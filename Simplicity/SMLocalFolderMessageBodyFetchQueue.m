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
    NSMutableArray *_nonUrgentfetchMessageBodyOpQueue;
    NSUInteger _activeIMAPOpCount;
}

- (id)initWithUserAccount:(SMUserAccount*)account localFolder:(SMLocalFolder*)localFolder {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _localFolder = localFolder;
        _fetchMessageBodyOps = [[SMFolderUIDDictionary alloc] init];
        _nonUrgentfetchMessageBodyOpQueue = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase {
    SM_LOG_DEBUG(@"uid %u, remote folder %@, threadId %llu, urgent %s", uid, remoteFolderName, threadId, urgent? "YES" : "NO");
    
    if([_localFolder.messageStorage messageHasData:uid localFolder:_localFolder.localName threadId:threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", uid);
        return;
    }
    
    if(tryLoadFromDatabase) {
        FetchOpDesc *opDesc = [[FetchOpDesc alloc] initWithUID:uid folderName:remoteFolderName];
        [_fetchMessageBodyOps setObject:opDesc forUID:uid folder:remoteFolderName];
        
        SMDatabaseOp *dbOp = [[_account.model database] loadMessageBodyForUIDFromDB:uid folderName:remoteFolderName urgent:urgent block:^(MCOMessageParser *parser, NSArray *attachments, NSString *messageBodyPreview) {
            FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
            if(currentOpDesc != opDesc) {
                // TODO: it happens suspiciously often...
                SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                return;
            }
            
            [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];

            if(parser == nil) {
                SM_LOG_DEBUG(@"Message UID %u (remote folder '%@') was found in the database, but its body count not be loaded; fetching from server now", uid, remoteFolderName);
                
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
                
        void (^fullOp)() = ^{
            FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
            if(currentOpDesc == nil) {
                if(!urgent) {
                    [_nonUrgentfetchMessageBodyOpQueue removeObject:opDesc];
                }
                
                SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                return;
            }
            
            MCOIMAPSession *session = [_account.model imapSession];
            NSAssert(session, @"session is nil");
            
            MCOIMAPFetchContentOperation *imapOp = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
            imapOp.urgent = urgent;

            currentOpDesc.imapOp = imapOp;
            
            _activeIMAPOpCount++;
            
            SM_LOG_DEBUG(@"Downloading body for message UID %u from folder '%@' started, attempt %lu (_activeIMAPOpCount %lu)", uid, remoteFolderName, currentOpDesc.attempt, _activeIMAPOpCount);
            
            [imapOp start:^(NSError * error, NSData * data) {
                NSAssert(_activeIMAPOpCount > 0, @"_activeIMAPOpCount is zero");
                
                _activeIMAPOpCount--;
                
                SM_LOG_DEBUG(@"Downloading body for message UID %u from folder '%@' ended (_activeIMAPOpCount %lu)", uid, remoteFolderName, _activeIMAPOpCount);

                FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
                if(currentOpDesc == nil) {
                    if(!urgent) {
                        [_nonUrgentfetchMessageBodyOpQueue removeObject:currentOpDesc];
                    }

                    SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                    return;
                }

                if(error == nil || [error code] == MCOErrorNone) {
                    [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];
                    
                    NSAssert(data != nil, @"data != nil");
                    
                    // TODO: do it asynchronously!
                    MCOMessageParser *parser = [MCOMessageParser messageParserWithData:data];
                    NSString *messageBodyPlainText = [SMMessage imapMessagePlainTextBody:parser];
                    
                    if(_localFolder.syncedWithRemoteFolder || _localFolder.kind == SMFolderKindSearch) {
                        [[_account.model database] putMessageBodyToDB:uid messageDate:messageDate data:data plainTextBody:messageBodyPlainText folderName:remoteFolderName];
                    }
                    
                    [self loadMessageBody:uid threadId:threadId parser:parser attachments:parser.attachments messageBodyPreview:messageBodyPlainText];
                    
                    if(!urgent) {
                        NSAssert(_nonUrgentfetchMessageBodyOpQueue.count > 0, @"no ops in the queue");
                        
                        [_nonUrgentfetchMessageBodyOpQueue removeObject:currentOpDesc];
                        
                        SM_LOG_DEBUG(@"fetch op finished (message UID %u, folder '%@'), body fetch op count: %lu", uid, remoteFolderName, _fetchMessageBodyOps.count);
                        
                        NSUInteger nextOpIndex = 0;
                        while(nextOpIndex < _nonUrgentfetchMessageBodyOpQueue.count) {
                            FetchOpDesc *nextOp = _nonUrgentfetchMessageBodyOpQueue[nextOpIndex];
                            
                            // skip all completed/urgent/cancelled ops
                            // also skip ops already being fetched
                            if([_fetchMessageBodyOps objectForUID:nextOp.uid folder:nextOp.folderName] != nil) {
                                if(nextOp.attempt == 0) {
                                    [nextOp startOp];
                                    break;
                                }
                                else {
                                    nextOpIndex++;
                                }
                            }
                            else {
                                [_nonUrgentfetchMessageBodyOpQueue removeObjectAtIndex:nextOpIndex];
                            }
                        }
                    }
                }
                else {
                    SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (%@); trying again...", uid, remoteFolderName, error);

                    // TODO!
                    // - move attempt count and retry delay to advanced prefs;
                    // - detect connectivity loss/restore.
                    [currentOpDesc performSelector:@selector(startOp) withObject:nil afterDelay:10];
                }
            }];
        };
        
        [opDesc setOp:fullOp];

        if(urgent) {
            [opDesc startOp];
        }
        else {
            [_nonUrgentfetchMessageBodyOpQueue addObject:opDesc];
            
            SM_LOG_DEBUG(@"new fetch op added (message UID %u, folder '%@'), non-urgent body op count: %lu", uid, remoteFolderName, _nonUrgentfetchMessageBodyOpQueue.count);
            
            if(_nonUrgentfetchMessageBodyOpQueue.count <= MAX_BODY_FETCH_OPS) {
                [opDesc startOp];
            }
        }
    }
}

- (void)loadMessageBody:(uint32_t)uid threadId:(uint64_t)threadId parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview {
    SMMessage *message = [_localFolder.messageStorage setMessageParser:parser attachments:attachments messageBodyPreview:messageBodyPreview uid:uid localFolder:_localFolder.localName threadId:threadId];
    
    if(message != nil) {
        [_localFolder increaseLocalFolderFootprint:message.messageSize];
        
        [SMNotificationsController localNotifyMessageBodyFetched:_localFolder.localName uid:uid threadId:threadId account:nil/*TODO*/];
    }
}

- (void)cancelBodyLoading:(uint32_t)uid remoteFolder:(NSString*)remoteFolder {
    // TODO: cancel if it's a DB op

    FetchOpDesc *opDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolder];
    if(opDesc) {
        [opDesc cancel];
    }
    
    [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolder];
}

- (void)stopBodiesLoading {
    [_fetchMessageBodyOps enumerateAllObjects:^(NSObject *obj) {
        FetchOpDesc *opDesc = (FetchOpDesc*)obj;
        [opDesc cancel];
    }];
    
    [_fetchMessageBodyOps removeAllObjects];
    
    [_nonUrgentfetchMessageBodyOpQueue removeAllObjects];
}

@end
