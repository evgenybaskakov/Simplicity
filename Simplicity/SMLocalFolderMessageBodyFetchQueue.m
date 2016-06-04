//
//  SMLocalFolderMessageBodyFetchQueue.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/23/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMFolderUIDDictionary.h"
#import "SMMessageStorage.h"
#import "SMDatabase.h"
#import "SMMessage.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderMessageBodyFetchQueue.h"

static const NSUInteger MAX_BODY_FETCH_OPS = 5;
static const NSUInteger FAILED_OP_RETRY_DELAY = 10;

@interface FetchOpDesc : NSObject
@property (readonly) uint32_t uid;
@property (readonly) NSString *folderName;
@property (readonly) NSUInteger attempt;
@property MCOIMAPFetchContentOperation *imapOp;
@property SMDatabaseOp *dbOp;
- (id)initWithUID:(uint32_t)uid folderName:(NSString*)folderName;
- (void)setOp:(void (^)())op;
- (void)startOp;
- (void)cancel;
@end

@implementation FetchOpDesc {
    void (^_op)();
}
- (id)initWithUID:(uint32_t)uid folderName:(NSString*)folderName {
    self = [super init];
    if(self) {
        _uid = uid;
        _folderName = folderName;
        _attempt = 0;
    }
    return self;
}
- (void)setOp:(void (^)())op {
    _op = op;
}
- (void)startOp {
    NSAssert(_op != nil, @"op is not set");

    _attempt++;
    _op();
}
- (void)cancel {
    if(_imapOp) {
        [_imapOp cancel];
    }
    
    if(_dbOp) {
        [_dbOp cancel];
    }
}
@end

@implementation SMLocalFolderMessageBodyFetchQueue {
    SMLocalFolder *__weak _localFolder;
    SMFolderUIDDictionary *_fetchMessageBodyOps;
    NSMutableArray<FetchOpDesc*> *_nonUrgentPendingOps;
    NSMutableSet<FetchOpDesc*> *_nonUrgentRunningOps;
    NSMutableSet<FetchOpDesc*> *_nonUrgentFailedOps;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolder:(SMLocalFolder*)localFolder {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _localFolder = localFolder;
        _fetchMessageBodyOps = [[SMFolderUIDDictionary alloc] init];
        _nonUrgentPendingOps = [NSMutableArray array];
        _nonUrgentRunningOps = [NSMutableSet set];
        _nonUrgentFailedOps = [NSMutableSet set];
    }
    
    return self;
}

- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase {
    SM_LOG_DEBUG(@"uid %u, remote folder %@, threadId %llu, urgent %s", uid, remoteFolderName, threadId, urgent? "YES" : "NO");
    
    NSAssert([(NSObject*)_localFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"bad local folder message storage type");
    if([(SMMessageStorage*)_localFolder.messageStorage messageHasData:uid threadId:threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", uid);
        return;
    }
    
    if(tryLoadFromDatabase) {
        FetchOpDesc *opDesc = [[FetchOpDesc alloc] initWithUID:uid folderName:remoteFolderName];
        [_fetchMessageBodyOps setObject:opDesc forUID:uid folder:remoteFolderName];
        
        FetchOpDesc *__weak blockOpDesc = opDesc;
        
        SMDatabaseOp *dbOp = [[_account database] loadMessageBodyForUIDFromDB:uid folderName:remoteFolderName urgent:urgent block:^(SMDatabaseOp *op, MCOMessageParser *parser, NSArray *attachments, NSString *messageBodyPreview) {
            FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
            if(currentOpDesc == nil || currentOpDesc != blockOpDesc) {
                SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                return;
            }
            
            [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];

            if(parser == nil) {
                SM_LOG_DEBUG(@"Message header with UID %u (remote folder '%@') was found in the database; body will be loaded from server", uid, remoteFolderName);
                
                [self fetchMessageBody:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId urgent:urgent tryLoadFromDatabase:NO];
            }
            else {
                [self loadMessageBody:uid threadId:threadId parser:parser attachments:attachments messageBodyPreview:messageBodyPreview];
            }
        }];

        opDesc.dbOp = dbOp;
    }
    else {
        if(urgent) {
            SM_LOG_DEBUG(@"Urgently downloading body for message UID %u from folder '%@'; there are %lu requests in the queue", uid, remoteFolderName, _fetchMessageBodyOps.count);
        }
        else {
            if([_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName] != nil) {
                SM_LOG_DEBUG(@"Body for message UID %u from folder '%@' is already being downloaded", uid, remoteFolderName);
                return;
            }
        }
        
        FetchOpDesc *opDesc = [[FetchOpDesc alloc] initWithUID:uid folderName:remoteFolderName];
        [_fetchMessageBodyOps setObject:opDesc forUID:uid folder:remoteFolderName];
        
        FetchOpDesc *__weak blockOpDesc = opDesc;
        
        void (^fullOp)() = ^{
            FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
            if(currentOpDesc == nil || currentOpDesc != blockOpDesc) {
                SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                return;
            }

            // If this is a re-trying operation, just schedule it on the regular basis.
            if([_nonUrgentFailedOps member:currentOpDesc] != nil) {
                [_nonUrgentFailedOps removeObject:currentOpDesc];
                [_nonUrgentPendingOps addObject:currentOpDesc];
                
                [self scheduleOp:currentOpDesc];
                
                return;
            }

            MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
            NSAssert(session, @"session is nil");
            
            MCOIMAPFetchContentOperation *imapOp = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
            imapOp.urgent = urgent;

            currentOpDesc.imapOp = imapOp;
            
            SM_LOG_DEBUG(@"Downloading body for message UID %u from folder '%@' started, attempt %lu", uid, remoteFolderName, currentOpDesc.attempt);
            
            [imapOp start:^(NSError * error, NSData * data) {
                SM_LOG_DEBUG(@"Downloading body for message UID %u from folder '%@' ended", uid, remoteFolderName);

                FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
                if(currentOpDesc == nil || currentOpDesc != blockOpDesc) {
                    SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                    return;
                }

                if(!urgent) {
                    NSAssert([_nonUrgentRunningOps member:currentOpDesc] != nil, @"op is not running");
                    [_nonUrgentRunningOps removeObject:currentOpDesc];
                }
                
                BOOL startNextOp = NO;
                if(error == nil || error.code == MCOErrorNone) {
                    [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];
                    
                    NSAssert(data != nil, @"data != nil");
                    
                    // TODO: do it asynchronously!
                    MCOMessageParser *parser = [MCOMessageParser messageParserWithData:data];
                    NSString *messageBodyPlainText = [SMMessage imapMessagePlainTextBody:parser];
                    
                    if(_localFolder.syncedWithRemoteFolder || _localFolder.kind == SMFolderKindSearch) {
                        [[_account database] putMessageBodyToDB:uid messageDate:messageDate data:data plainTextBody:messageBodyPlainText folderName:remoteFolderName];
                    }

                    if(!urgent) {
                        SM_LOG_DEBUG(@"fetch op finished (message UID %u, folder '%@'), body fetch op count: %lu", uid, remoteFolderName, _fetchMessageBodyOps.count);
                        
                        startNextOp = YES;
                    }
                    
                    [self loadMessageBody:uid threadId:threadId parser:parser attachments:parser.attachments messageBodyPreview:messageBodyPlainText];
                }
                else {
                    SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (%@); trying again...", uid, remoteFolderName, error);

                    if(!urgent) {
                        [_nonUrgentRunningOps removeObject:currentOpDesc];
                        [_nonUrgentFailedOps addObject:currentOpDesc];

                        startNextOp = YES;
                    }

                    // TODO!
                    // - move attempt count and retry delay to advanced prefs;
                    // - detect connectivity loss/restore.
                    [currentOpDesc performSelector:@selector(startOp) withObject:nil afterDelay:FAILED_OP_RETRY_DELAY];
                }
                
                if(startNextOp && _nonUrgentPendingOps.count > 0) {
                    NSUInteger nextOpIndex = 0;

                    FetchOpDesc *nextOp = _nonUrgentPendingOps[nextOpIndex];
                    [_nonUrgentPendingOps removeObjectAtIndex:nextOpIndex];
                    [_nonUrgentRunningOps addObject:nextOp];
                    
                    [nextOp startOp];
                }
            }];
        };
        
        [opDesc setOp:fullOp];

        if(urgent) {
            [opDesc startOp];
        }
        else {
            [self scheduleOp:opDesc];
        }
    }
}

- (void)scheduleOp:(FetchOpDesc*)opDesc {
    if(_nonUrgentRunningOps.count < MAX_BODY_FETCH_OPS) {
        [opDesc startOp];
        
        [_nonUrgentRunningOps addObject:opDesc];
        
        SM_LOG_DEBUG(@"new running op added (message UID %u, folder '%@'), total %lu running ops", opDesc.uid, opDesc.folderName, _nonUrgentRunningOps.count);
    }
    else {
        [_nonUrgentPendingOps addObject:opDesc];
        
        SM_LOG_DEBUG(@"new pending op added (message UID %u, folder '%@'), total %lu pending ops", opDesc.uid, opDesc.folderName, _nonUrgentPendingOps.count);
    }
}

- (void)loadMessageBody:(uint32_t)uid threadId:(uint64_t)threadId parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview {
    NSAssert([(NSObject*)_localFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"bad local folder message storage type");
    SMMessage *message = [(SMMessageStorage*)_localFolder.messageStorage setMessageParser:parser attachments:attachments messageBodyPreview:messageBodyPreview uid:uid threadId:threadId];
    
    if(message != nil) {
        [_localFolder increaseLocalFolderFootprint:message.messageSize];
        
        [SMNotificationsController localNotifyMessageBodyFetched:_localFolder uid:uid threadId:threadId account:(SMUserAccount*)_account];
    }
}

- (void)cancelBodyLoading:(uint32_t)uid remoteFolder:(NSString*)remoteFolder {
    FetchOpDesc *opDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolder];
    if(opDesc) {
        [opDesc cancel];
        
        [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolder];
        [_nonUrgentPendingOps removeObject:opDesc];
        [_nonUrgentRunningOps removeObject:opDesc];
        [_nonUrgentFailedOps removeObject:opDesc];
    }
}

- (void)stopBodiesLoading {
    [_fetchMessageBodyOps enumerateAllObjects:^(NSObject *obj) {
        FetchOpDesc *opDesc = (FetchOpDesc*)obj;
        [opDesc cancel];
    }];
    
    [_fetchMessageBodyOps removeAllObjects];
    [_nonUrgentPendingOps removeAllObjects];
    [_nonUrgentRunningOps removeAllObjects];
    [_nonUrgentFailedOps removeAllObjects];
}

@end
