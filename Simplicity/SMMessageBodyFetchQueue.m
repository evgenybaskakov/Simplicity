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
static const NSUInteger MAX_OP_ATTEMPTS = 5;
static const NSUInteger SERVER_OP_TIMEOUT_SEC = 30;

@interface FetchOpDesc : NSObject
@property (readonly) uint32_t uid;
@property (readonly) uint64_t threadId;
@property (readonly) NSDate *messageDate;
@property (readonly) NSString *remoteFolder;
@property (readonly) SMLocalFolder *localFolder;
@property (readonly) NSUInteger attempt;
@property (readonly) BOOL urgent;
@property (readonly) NSDate *startTime;
@property (readonly) NSDate *updateTime;
@property (readonly) unsigned int bytesLoaded;
@property (readonly) unsigned int bytesTotal;
@property MCOIMAPFetchContentOperation *remoteOp;
@property SMDatabaseOp *dbOp;
- (id)initWithUID:(uint32_t)uid threadId:(uint64_t)threadId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder urgent:(BOOL)urgent;
- (void)newAttempt;
- (void)cancel;
@end

@implementation FetchOpDesc

- (id)initWithUID:(uint32_t)uid threadId:(uint64_t)threadId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder urgent:(BOOL)urgent {
    self = [super init];
    if(self) {
        _uid = uid;
        _threadId = threadId;
        _messageDate = messageDate;
        _remoteFolder = remoteFolder;
        _localFolder = localFolder;
        _urgent = urgent;
        _attempt = 0;
        _bytesLoaded = 0;
        _bytesTotal = UINT32_MAX;
    }
    return self;
}

- (void)newAttempt {
    if(_attempt == 0) {
        _startTime = [NSDate date];
    }
    _updateTime = [NSDate date];
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

- (void)updateProgress:(uint32_t)loaded total:(uint32_t)total {
    if(loaded != _bytesLoaded && total != _bytesTotal) {
        _updateTime = [NSDate date];
        _bytesLoaded = loaded;
        _bytesTotal = total;
    }
}

@end

@implementation SMMessageBodyFetchQueue {
    NSMutableDictionary<NSString*, SMFolderUIDDictionary*> *_fetchOps;
    NSMutableArray<FetchOpDesc*> *_nonUrgentPendingOps;
    NSMutableSet<FetchOpDesc*> *_nonUrgentRunningOps;
    NSMutableSet<FetchOpDesc*> *_nonUrgentFailedOps;
    BOOL _emptyNotificationSent, _notEmptyNotificationSent;
    BOOL _queuePaused;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _fetchOps = [NSMutableDictionary dictionary];
        _nonUrgentPendingOps = [NSMutableArray array];
        _nonUrgentRunningOps = [NSMutableSet set];
        _nonUrgentFailedOps = [NSMutableSet set];
        _emptyNotificationSent = NO;
        _notEmptyNotificationSent = NO;
        _queuePaused = NO;
        
        [self scheduleTimeoutCheck];
    }
    
    return self;
}

- (void)dealloc {
    [self cancelTimeoutCheck];
}

- (void)sendEmptyNotification {
    if(!_emptyNotificationSent) {
        [SMNotificationsController localNotifyMessageBodyFetchQueueEmpty:self account:(SMUserAccount*)_account];
        
        _emptyNotificationSent = YES;
        _notEmptyNotificationSent = NO;
    }
}

- (void)sendNotEmptyNotification {
    if(!_notEmptyNotificationSent) {
        [SMNotificationsController localNotifyMessageBodyFetchQueueNotEmpty:self account:(SMUserAccount*)_account];
        
        _notEmptyNotificationSent = YES;
        _emptyNotificationSent = NO;
    }
}

- (FetchOpDesc*)getFetchOp:(uint32_t)uid remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder {
    return (FetchOpDesc*)[[_fetchOps objectForKey:localFolder.localName] objectForUID:uid folder:remoteFolder];
}

- (void)addFetchOp:(FetchOpDesc*)op {
    SMFolderUIDDictionary *dict = [_fetchOps objectForKey:op.localFolder.localName];
    
    if(dict == nil) {
        dict = [[SMFolderUIDDictionary alloc] init];
        [_fetchOps setObject:dict forKey:op.localFolder.localName];
    }
    
    [dict setObject:op forUID:op.uid folder:op.remoteFolder];
}

- (void)removeFetchOp:(FetchOpDesc*)op {
    SMFolderUIDDictionary *dict = [_fetchOps objectForKey:op.localFolder.localName];
    
    if(dict != nil) {
        [dict removeObjectforUID:op.uid folder:op.remoteFolder];

        if(dict.count == 0) {
            [_fetchOps removeObjectForKey:op.localFolder.localName];
        }
    }
}

- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder {
    SM_LOG_DEBUG(@"uid %u, remote folder %@, threadId %llu, urgent %s", uid, remoteFolder, threadId, urgent? "YES" : "NO");
    
    NSAssert([(NSObject*)localFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"bad local folder message storage type");
    if([(SMMessageStorage*)localFolder.messageStorage messageHasData:uid threadId:threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", uid);
        return;
    }
    
    FetchOpDesc *existingOpDesc = [self getFetchOp:uid remoteFolder:remoteFolder localFolder:localFolder];
    if(existingOpDesc != nil && !(urgent && !existingOpDesc.urgent)) {
        SM_LOG_DEBUG(@"message body for uid %u is already being loaded", uid);
        return;
    }
    
    FetchOpDesc *opDesc = [[FetchOpDesc alloc] initWithUID:uid threadId:threadId messageDate:messageDate remoteFolder:remoteFolder localFolder:localFolder urgent:urgent];
    
    [self addFetchOp:opDesc];

    if(tryLoadFromDatabase) {
        [self startFetchingDBOp:opDesc];
    }
    else {
        if(urgent) {
            [self startFetchingRemoteOp:opDesc];
        }
        else {
            [self scheduleRemoteOp:opDesc];
        }
    }
}

- (void)startNextRemoteOp {
    if(_queuePaused) {
        return;
    }
    
    while(_nonUrgentPendingOps.count > 0 && _nonUrgentRunningOps.count < MAX_BODY_FETCH_OPS) {
        NSUInteger nextOpIndex = 0;
        
        FetchOpDesc *nextOp = _nonUrgentPendingOps[nextOpIndex];
        NSAssert([nextOp isKindOfClass:[FetchOpDesc class]], @"unknown op class");
        
        [_nonUrgentPendingOps removeObjectAtIndex:nextOpIndex];
        
        [self startFetchingRemoteOp:nextOp];
    }
    
    if(_nonUrgentRunningOps.count == 0 && _nonUrgentFailedOps.count == 0) {
        [self sendEmptyNotification];
    }
}

- (void)scheduleRemoteOp:(FetchOpDesc*)op {
    NSAssert([op isKindOfClass:[FetchOpDesc class]], @"unknown op class");
        
    if(!_queuePaused && _nonUrgentRunningOps.count < MAX_BODY_FETCH_OPS) {
        NSAssert(![_nonUrgentRunningOps containsObject:op], @"op already running");
        
        [self startFetchingRemoteOp:op];
        
        SM_LOG_DEBUG(@"new running op added (message UID %u, folder '%@'), total %lu running ops", op.uid, op.remoteFolder, _nonUrgentRunningOps.count);
    }
    else {
        [_nonUrgentPendingOps addObject:op];
        
        SM_LOG_DEBUG(@"new pending op added (message UID %u, folder '%@'), total %lu pending ops", op.uid, op.remoteFolder, _nonUrgentPendingOps.count);
    }
}

- (void)startFetchingDBOp:(FetchOpDesc*)opDesc {
    // TODO: Actually, DB ops in a paused queue should not be executed.
    //       However, they are not pausable right now. We can live with that.
    SMDatabaseOp *dbOp = [[opDesc.localFolder.account database] loadMessageBodyForUIDFromDB:opDesc.uid folderName:opDesc.remoteFolder urgent:opDesc.urgent block:^(SMDatabaseOp *op, MCOMessageParser *parser, NSArray *attachments, NSString *plainTextBody) {
        if([self getFetchOp:opDesc.uid remoteFolder:opDesc.remoteFolder localFolder:opDesc.localFolder] == nil) {
            SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (cancelled)", opDesc.uid, opDesc.remoteFolder);
            return;
        }
        
        [self removeFetchOp:opDesc];
        
        if(![(SMMessageStorage*)opDesc.localFolder.messageStorage messageHasData:opDesc.uid threadId:opDesc.threadId]) {
            if(parser == nil) {
                SM_LOG_DEBUG(@"Message header with UID %u (remote folder '%@') was found in the database; body will be loaded from server", opDesc.uid, opDesc.remoteFolder);
                
                // Re-try, this time load from the server.
                [self fetchMessageBody:opDesc.uid messageDate:opDesc.messageDate threadId:opDesc.threadId urgent:opDesc.urgent tryLoadFromDatabase:NO remoteFolder:opDesc.remoteFolder localFolder:opDesc.localFolder];
            }
            else {
                BOOL hasAttachments = (attachments.count > 0);
                
                [self loadMessageBody:opDesc.uid threadId:opDesc.threadId parser:parser attachments:attachments hasAttachments:hasAttachments plainTextBody:plainTextBody localFolder:opDesc.localFolder];
            }
        }
        else {
            SM_LOG_DEBUG(@"Loading body for message UID %u from folder '%@' skipped (already loaded)", opDesc.uid, opDesc.remoteFolder);
        }
    }];
    
    opDesc.dbOp = dbOp;
}

- (void)startFetchingRemoteOp:(FetchOpDesc*)op {
    // First check if the message already has its body loaded.
    if([(SMMessageStorage*)op.localFolder.messageStorage messageHasData:op.uid threadId:op.threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", op.uid);

        [self startNextRemoteOp];
        return;
    }
    
    // Now check if the operation has been cancelled.
    if([self getFetchOp:op.uid remoteFolder:op.remoteFolder localFolder:op.localFolder] == nil) {
        SM_LOG_DEBUG(@"message body loading for uid %u is cancelled", op.uid);

        [self startNextRemoteOp];
        return;
    }

    // If this is a re-trying operation, just schedule it on the regular basis.
    if([_nonUrgentFailedOps member:op] != nil) {
        SM_LOG_INFO(@"retrying body downloading for message UID %u from folder '%@'", op.uid, op.remoteFolder);
        
        [_nonUrgentFailedOps removeObject:op];
        [self scheduleRemoteOp:op];
        return;
    }
    
    // Finally, check if the queue is active.
    // If not, with everything in place it will be resumed fully functional.
    if(_queuePaused) {
        SM_LOG_DEBUG(@"queue paused");
        return;
    }
    
    // Now, looks like this is an actual operation the user wants to complete. Go for it.
    if(!op.urgent) {
        [_nonUrgentRunningOps addObject:op];

        [self sendNotEmptyNotification];
    }
    
    [op newAttempt];
    
    MCOIMAPSession *session = [(SMUserAccount*)op.localFolder.account imapSession];
    NSAssert(session, @"session is nil");
    
    MCOIMAPFetchContentOperation *imapOp = [session fetchMessageOperationWithFolder:op.remoteFolder uid:op.uid urgent:op.urgent];
    imapOp.urgent = op.urgent;
    
    op.remoteOp = imapOp;
    
    SM_LOG_INFO(@"Body download for message UID %u from folder '%@' started, attempt %lu (%@)", op.uid, op.remoteFolder, op.attempt, op.urgent? @"urgent" : @"non-urgent");

    __weak FetchOpDesc *weakOpDesc = op;
    imapOp.progress = ^(unsigned int current, unsigned int maximum) {
        FetchOpDesc *opDesc = weakOpDesc;
        if(opDesc == nil) {
            return;
        }
        
        SM_LOG_NOISE(@"Message UID %u, folder '%@' progress %u / %u", weakOpDesc.uid, weakOpDesc.remoteFolder, current, maximum);

        [opDesc updateProgress:current total:maximum];
    };

    [imapOp start:^(NSError *error, NSData *data) {
        SM_LOG_DEBUG(@"Body download for message UID %u from folder '%@' ended", op.uid, op.remoteFolder);

        if(!op.urgent) {
            if(![_nonUrgentRunningOps containsObject:op]) {
                SM_LOG_INFO(@"Body download for message UID %u from folder '%@' skipped (cancelled)", op.uid, op.remoteFolder);
                
                [self startNextRemoteOp];
                return;
            }
            
            [_nonUrgentRunningOps removeObject:op];
        }
        
        if([self getFetchOp:op.uid remoteFolder:op.remoteFolder localFolder:op.localFolder] == nil) {
            SM_LOG_INFO(@"Body download for message UID %u from folder '%@' skipped (completed before or cancelled)", op.uid, op.remoteFolder);

            [self startNextRemoteOp];
            return;
        }
        
        if(error == nil || error.code == MCOErrorNone) {
            SM_LOG_INFO(@"fetch op finished (message UID %u, folder '%@'), attempts %lu (time %g sec)", op.uid, op.remoteFolder, op.attempt, [[NSDate date] timeIntervalSinceDate:op.startTime]);

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
                    if([self getFetchOp:op.uid remoteFolder:op.remoteFolder localFolder:op.localFolder] == nil) {
                        SM_LOG_INFO(@"Body download for message UID %u from folder '%@' skipped (completed before or cancelled)", op.uid, op.remoteFolder);
                        
                        [self startNextRemoteOp];
                        return;
                    }
                    
                    FetchOpDesc *pendingOp = [self getFetchOp:op.uid remoteFolder:op.remoteFolder localFolder:op.localFolder];
                    [self removeFetchOp:op];
                    
                    if(op.localFolder.syncedWithRemoteFolder || op.localFolder.kind == SMFolderKindSearch) {
                        [[op.localFolder.account database] putMessageBodyToDB:op.uid messageDate:op.messageDate data:data plainTextBody:plainTextBody folderName:op.remoteFolder];
                        
                        if(hasAttachments) {
                            [[op.localFolder.account database] updateMessageAttributesInDBFolder:op.uid hasAttachments:YES folder:op.remoteFolder];
                        }
                    }
                    
                    // For non-urgent operations, just don't propagate the heavy parts, the message parser and attachments.
                    // They are needed only to decode the HTML part and actually load the files, that is, when the user looks at that message.
                    MCOMessageParser *loadedMessageParser = nil;
                    NSArray *loadedAttachments = nil;
                    
                    if(op.urgent || pendingOp.urgent) {
                        loadedMessageParser = parser;
                        loadedAttachments = attachments;
                    }
                    
                    [self loadMessageBody:op.uid threadId:op.threadId parser:loadedMessageParser attachments:loadedAttachments hasAttachments:hasAttachments plainTextBody:plainTextBody localFolder:op.localFolder];
                });
            });
        }
        else {
            SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (%@), %lu attempts made", op.uid, op.remoteFolder, error, op.attempt);
            
            if(op.attempt < MAX_OP_ATTEMPTS) {
                if(!op.urgent) {
                    [_nonUrgentFailedOps addObject:op];
                }
                
                // TODO!
                // - move attempt count and retry delay to advanced prefs;
                // - detect connectivity loss/restore.
                [self performSelector:@selector(startFetchingRemoteOp:) withObject:op afterDelay:FAILED_OP_RETRY_DELAY];
            }
            else {
                SM_LOG_ERROR(@"Message body for uid %u, remote folder %@ (%@) is cancelling as failed", op.uid, op.remoteFolder, error);

                [self removeFetchOp:op];
                
                // TODO: notify the user
            }
        }
        
        [self startNextRemoteOp];
    }];
}

- (void)loadMessageBody:(uint32_t)uid threadId:(uint64_t)threadId parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody localFolder:(SMLocalFolder*)localFolder {
    NSAssert([(NSObject*)localFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"bad local folder message storage type");
    SMMessage *message = [(SMMessageStorage*)localFolder.messageStorage setMessageParser:parser attachments:attachments hasAttachments:hasAttachments plainTextBody:plainTextBody uid:uid threadId:threadId];
    
    if(message != nil) {
        [localFolder increaseLocalFolderFootprint:message.messageSize];
        
        [SMNotificationsController localNotifyMessageBodyFetched:localFolder uid:uid threadId:threadId account:(SMUserAccount*)localFolder.account];
    }
}

- (void)cancelBodyFetch:(uint32_t)uid remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder *)localFolder {
    FetchOpDesc *opDesc = [self getFetchOp:uid remoteFolder:remoteFolder localFolder:localFolder];
    if(opDesc) {
        [opDesc cancel];
        
        [_nonUrgentPendingOps removeObject:opDesc];
        [_nonUrgentRunningOps removeObject:opDesc];
        [_nonUrgentFailedOps removeObject:opDesc];
        
        [self removeFetchOp:opDesc];
        [self startNextRemoteOp];
    }
}

- (void)pauseBodyFetchQueue {
    if(_queuePaused) {
        return;
    }
    
    // TODO
    
    _queuePaused = YES;
}

- (void)resumeBodyFetchQueue {
    if(!_queuePaused) {
        return;
    }

    _queuePaused = NO;

    [self startNextRemoteOp];
}

- (void)stopBodyFetchQueue {
    for(NSString *localFolderName in _fetchOps.allKeys) {
        SMFolderUIDDictionary *dict = [_fetchOps objectForKey:localFolderName];
        
        [dict enumerateAllObjects:^(NSObject *obj) {
            FetchOpDesc *opDesc = (FetchOpDesc*)obj;
            [opDesc cancel];
        }];
    }
    
    for(FetchOpDesc *op in _nonUrgentRunningOps) {
        SM_LOG_INFO(@"cancelling running body download for uid %u, folder %@", op.uid, op.remoteFolder);
        [op cancel];
    }
    
    [_fetchOps removeAllObjects];

    [_nonUrgentPendingOps removeAllObjects];
    [_nonUrgentRunningOps removeAllObjects];
    [_nonUrgentFailedOps removeAllObjects];

    _queuePaused = NO;
}

- (void)scheduleTimeoutCheck {
    [self performSelector:@selector(serverOpTimeoutCheck) withObject:nil afterDelay:SERVER_OP_TIMEOUT_SEC];
}

- (void)cancelTimeoutCheck {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)serverOpTimeoutCheck {
    [self scheduleTimeoutCheck];

    if(_nonUrgentRunningOps.count == 0) {
        return;
    }
    
    NSMutableSet *timedOutOps = [NSMutableSet set];
    NSDate *currentTime = [NSDate date];
    
    for(FetchOpDesc *op in _nonUrgentRunningOps) {
        if([currentTime timeIntervalSinceDate:op.updateTime] >= SERVER_OP_TIMEOUT_SEC) {
            [timedOutOps addObject:op];
        }
    }

    if(timedOutOps.count == 0) {
        return;
    }
    
    for(FetchOpDesc *op in _nonUrgentRunningOps) {
        SM_LOG_WARNING(@"Message body stuck for UID %u, remote folder '%@'", op.uid, op.remoteFolder);
    }
    
    // TODO: use op attempt count to decide when to stop trying
    for(FetchOpDesc *op in timedOutOps) {
        [_nonUrgentRunningOps removeObject:op];
        [_nonUrgentPendingOps addObject:op];
    }

    for(NSUInteger i = 0; i < timedOutOps.count; i++) {
        [self startNextRemoteOp];
    }
}

@end
