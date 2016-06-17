//
//  SMMessageBodyFetchQueue.m
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
#import "SMMessageBodyFetchQueue.h"

static const NSUInteger MAX_BODY_FETCH_OPS = 5;
static const NSUInteger FAILED_OP_RETRY_DELAY = 10;

@interface FetchOpDesc : NSObject
@property (readonly) uint32_t uid;
@property (readonly) uint64_t threadId;
@property (readonly) NSDate *messageDate;
@property (readonly) NSString *folderName;
@property (readonly) NSUInteger attempt;
@property (readonly) BOOL urgent;
@property (readonly) NSDate *startTime;
@property MCOIMAPFetchContentOperation *remoteOp;
@property SMDatabaseOp *dbOp;
- (id)initWithUID:(uint32_t)uid threadId:(uint64_t)threadId messageDate:(NSDate*)messageDate folderName:(NSString*)folderName urgent:(BOOL)urgent;
- (void)newAttempt;
- (void)cancel;
@end

@implementation FetchOpDesc

- (id)initWithUID:(uint32_t)uid threadId:(uint64_t)threadId messageDate:(NSDate*)messageDate folderName:(NSString*)folderName urgent:(BOOL)urgent {
    self = [super init];
    if(self) {
        _uid = uid;
        _threadId = threadId;
        _messageDate = messageDate;
        _folderName = folderName;
        _urgent = urgent;
        _attempt = 0;
    }
    return self;
}

- (void)newAttempt {
    if(_attempt == 0) {
        _startTime = [NSDate date];
    }
    _attempt++;
}

- (void)cancel {
    if(_remoteOp) {
        [_remoteOp cancel];
    }
    
    if(_dbOp) {
        [_dbOp cancel];
    }
}

@end

@implementation SMMessageBodyFetchQueue {
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
    
    FetchOpDesc *existingOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
    if(existingOpDesc != nil && !(urgent && !existingOpDesc.urgent)) {
        SM_LOG_DEBUG(@"message body for uid %u is already being loaded", uid);
        return;
    }
    
    if(tryLoadFromDatabase) {
        FetchOpDesc *opDesc = [[FetchOpDesc alloc] initWithUID:uid threadId:threadId messageDate:messageDate folderName:remoteFolderName urgent:urgent];
        [_fetchMessageBodyOps setObject:opDesc forUID:uid folder:remoteFolderName];
        
        SMDatabaseOp *dbOp = [[_account database] loadMessageBodyForUIDFromDB:uid folderName:remoteFolderName urgent:urgent block:^(SMDatabaseOp *op, MCOMessageParser *parser, NSArray *attachments, NSString *plainTextBody) {
            if((FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName] == nil) {
                SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (cancelled)", uid, remoteFolderName);
                return;
            }
            
            [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];
            
            if(![(SMMessageStorage*)_localFolder.messageStorage messageHasData:uid threadId:threadId]) {
                if(parser == nil) {
                    SM_LOG_DEBUG(@"Message header with UID %u (remote folder '%@') was found in the database; body will be loaded from server", uid, remoteFolderName);
                    
                    // Re-try, this time load from the server.
                    [self fetchMessageBody:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId urgent:urgent tryLoadFromDatabase:NO];
                }
                else {
                    [self loadMessageBody:uid threadId:threadId parser:parser attachments:attachments plainTextBody:plainTextBody];
                }
            }
            else {
                SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (already loaded)", uid, remoteFolderName);
            }
        }];
        
        opDesc.dbOp = dbOp;
    }
    else {
        FetchOpDesc *newOpDesc = [[FetchOpDesc alloc] initWithUID:uid threadId:threadId messageDate:messageDate folderName:remoteFolderName urgent:urgent];
        [_fetchMessageBodyOps setObject:newOpDesc forUID:uid folder:remoteFolderName];
        
        if(urgent) {
            [self startFetchingRemoteOp:newOpDesc];
        }
        else {
            [self scheduleRemoteOp:newOpDesc];
        }
    }
}

- (void)startNextRemoteOp {
    if(_nonUrgentPendingOps.count > 0 && _nonUrgentRunningOps.count < MAX_BODY_FETCH_OPS) {
        NSUInteger nextOpIndex = 0;
        
        FetchOpDesc *nextOp = _nonUrgentPendingOps[nextOpIndex];
        NSAssert([nextOp isKindOfClass:[FetchOpDesc class]], @"unknown op class");
        
        [_nonUrgentPendingOps removeObjectAtIndex:nextOpIndex];
        
        [self startFetchingRemoteOp:nextOp];
    }
}

- (void)scheduleRemoteOp:(FetchOpDesc*)op {
    NSAssert([op isKindOfClass:[FetchOpDesc class]], @"unknown op class");
    
    if(_nonUrgentRunningOps.count < MAX_BODY_FETCH_OPS) {
        NSAssert(![_nonUrgentRunningOps containsObject:op], @"op already running");
        
        [self startFetchingRemoteOp:op];
        
        SM_LOG_DEBUG(@"new running op added (message UID %u, folder '%@'), total %lu running ops", op.uid, op.folderName, _nonUrgentRunningOps.count);
    }
    else {
        [_nonUrgentPendingOps addObject:op];
        
        SM_LOG_DEBUG(@"new pending op added (message UID %u, folder '%@'), total %lu pending ops", op.uid, op.folderName, _nonUrgentPendingOps.count);
    }
}

- (void)startFetchingRemoteOp:(FetchOpDesc*)op {
    // First check if the message already has its body loaded.
    if([(SMMessageStorage*)_localFolder.messageStorage messageHasData:op.uid threadId:op.threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", op.uid);

        [self startNextRemoteOp];
        return;
    }
    
    // Now check if the operation hass been cancelled.
    if((FetchOpDesc*)[_fetchMessageBodyOps objectForUID:op.uid folder:op.folderName] == nil) {
        SM_LOG_DEBUG(@"message body loading for uid %u is cancelled", op.uid);

        [self startNextRemoteOp];
        return;
    }

    // If this is a re-trying operation, just schedule it on the regular basis.
    if([_nonUrgentFailedOps member:op] != nil) {
        SM_LOG_INFO(@"retrying body downloading for message UID %u from folder '%@'", op.uid, op.folderName);
        
        [_nonUrgentFailedOps removeObject:op];
        [self scheduleRemoteOp:op];
        return;
    }
    
    // Now, looks like this is an actual operation the user wants to complete. Go for it.
    if(!op.urgent) {
        [_nonUrgentRunningOps addObject:op];
    }
    
    [op newAttempt];
    
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    NSAssert(session, @"session is nil");
    
    MCOIMAPFetchContentOperation *imapOp = [session fetchMessageOperationWithFolder:op.folderName uid:op.uid urgent:op.urgent];
    imapOp.urgent = op.urgent;
    
    op.remoteOp = imapOp;
    
    SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' started, attempt %lu", op.uid, op.folderName, op.attempt);
    
    [imapOp start:^(NSError * error, NSData * data) {
        SM_LOG_DEBUG(@"Downloading body for message UID %u from folder '%@' ended", op.uid, op.folderName);
        
        [_nonUrgentRunningOps removeObject:op];
        
        if((FetchOpDesc*)[_fetchMessageBodyOps objectForUID:op.uid folder:op.folderName] == nil) {
            SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", op.uid, op.folderName);

            [self startNextRemoteOp];
            return;
        }
        
        if(error == nil || error.code == MCOErrorNone) {
            SM_LOG_INFO(@"fetch op finished (message UID %u, folder '%@'), attempts %lu (time %g sec)", op.uid, op.folderName, op.attempt, [[NSDate date] timeIntervalSinceDate:op.startTime]);

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSAssert(data != nil, @"data != nil");
                
                // Decoding plain text body and attachments can be resource consuming, so do it asynchronously
                MCOMessageParser *parser = [MCOMessageParser messageParserWithData:data];
                NSArray *attachments = parser.attachments;
                BOOL hasAttachments = attachments.count != 0;
                NSString *plainTextBody = parser.plainTextBodyRendering;
                if(plainTextBody == nil) {
                    plainTextBody = @"";
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if((FetchOpDesc*)[_fetchMessageBodyOps objectForUID:op.uid folder:op.folderName] == nil) {
                        SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", op.uid, op.folderName);
                        
                        [self startNextRemoteOp];
                        return;
                    }
 
                    [_fetchMessageBodyOps removeObjectforUID:op.uid folder:op.folderName];
                    
                    if(_localFolder.syncedWithRemoteFolder || _localFolder.kind == SMFolderKindSearch) {
                        [[_account database] putMessageBodyToDB:op.uid messageDate:op.messageDate data:data plainTextBody:plainTextBody folderName:op.folderName];
                        
                        if(hasAttachments) {
                            [[_account database] updateMessageAttributesInDBFolder:op.uid hasAttachments:YES folder:op.folderName];
                        }
                    }
                    
                    [self loadMessageBody:op.uid threadId:op.threadId parser:parser attachments:attachments plainTextBody:plainTextBody];
                });
            });
        }
        else {
            SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (%@); trying again (%lu attempts)...", op.uid, op.folderName, error, op.attempt);
            
            if(!op.urgent) {
                [_nonUrgentFailedOps addObject:op];
            }
            
            // TODO!
            // - move attempt count and retry delay to advanced prefs;
            // - detect connectivity loss/restore.
            [self performSelector:@selector(startFetchingRemoteOp:) withObject:op afterDelay:FAILED_OP_RETRY_DELAY];
        }
        
        [self startNextRemoteOp];
    }];
}

- (void)loadMessageBody:(uint32_t)uid threadId:(uint64_t)threadId parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments plainTextBody:(NSString*)plainTextBody {
    NSAssert([(NSObject*)_localFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"bad local folder message storage type");
    SMMessage *message = [(SMMessageStorage*)_localFolder.messageStorage setMessageParser:parser attachments:attachments plainTextBody:plainTextBody uid:uid threadId:threadId];
    
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
        
        [self startNextRemoteOp];
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
