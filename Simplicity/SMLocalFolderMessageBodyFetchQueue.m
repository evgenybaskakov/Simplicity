//
//  SMLocalFolderMessageBodyFetchQueue.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/23/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMessageStorage.h"
#import "SMDatabase.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderMessageBodyFetchQueue.h"

static const NSUInteger MAX_BODY_FETCH_OPS = 5;

@interface FetchOpDesc : NSObject
@property (readonly) NSUInteger opId;
@property (readonly) void (^op)();
- (id)initWithOpId:(NSUInteger)opId op:(void (^)())op;
@end

@implementation FetchOpDesc
- (id)initWithOpId:(NSUInteger)opId op:(void (^)())op {
    self = [super init];
    if(self) {
        _opId = opId;
        _op = op;
    }
    return self;
}
@end

@implementation SMLocalFolderMessageBodyFetchQueue {
    SMLocalFolder *__weak _localFolder;
    NSMutableDictionary *_fetchMessageBodyOps;
    NSMutableArray *_nonUrgentfetchMessageBodyOpQueue;
    NSUInteger _nextFetchOpId;
}

- (id)initWithLocalFolder:(SMLocalFolder*)localFolder {
    self = [super init];
    
    if(self) {
        _localFolder = localFolder;
        _fetchMessageBodyOps = [NSMutableDictionary new];
        _nonUrgentfetchMessageBodyOpQueue = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase {
    SM_LOG_INFO(@"uid %u, remote folder %@, threadId %llu, urgent %s", uid, remoteFolderName, threadId, urgent? "YES" : "NO");
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    
    if([[[appDelegate model] messageStorage] messageHasData:uid localFolder:_localFolder.localName threadId:threadId]) {
        SM_LOG_DEBUG(@"message body for uid %u already loaded", uid);
        return;
    }
    
    if(!tryLoadFromDatabase || ![[[appDelegate model] database] loadMessageBodyForUIDFromDB:uid folderName:remoteFolderName urgent:urgent block:^(NSData *data, MCOMessageParser *parser, NSArray *attachments) {
        if(data == nil) {
            SM_LOG_DEBUG(@"Message UID %u (remote folder '%@') was found in the database, but its body count not be loaded; fetching from server now", uid, remoteFolderName);
            
            [self fetchMessageBody:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId urgent:urgent tryLoadFromDatabase:NO];
        }
        else {
            [self loadMessageBody:uid threadId:threadId data:data parser:parser attachments:attachments];
        }
    }]) {
        if(urgent) {
            SM_LOG_INFO(@"Urgently downloading body for message UID %u from folder '%@'; there are %lu requests in the queue", uid, remoteFolderName, _fetchMessageBodyOps.count);
        }
        
        MCOIMAPSession *session = [[appDelegate model] imapSession];
        NSAssert(session, @"session is nil");
        
        MCOIMAPFetchContentOperation *op = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
        op.urgent = urgent;
        
        NSUInteger opId = _nextFetchOpId++;
        
        [_fetchMessageBodyOps setObject:op forKey:[NSNumber numberWithUnsignedInt:uid]];
        
        void (^fullOp)() = ^{
            void (^opBlock)(NSError *error, NSData *data) = nil;
            
            opBlock = ^(NSError * error, NSData * data) {
                SM_LOG_DEBUG(@"msg uid %u", uid);
                
                if(error == nil || [error code] == MCOErrorNone) {
                    [_fetchMessageBodyOps removeObjectForKey:[NSNumber numberWithUnsignedInt:uid]];
                    
                    NSAssert(data != nil, @"data != nil");
                    
                    if(_localFolder.syncedWithRemoteFolder) {
                        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                        [[[appDelegate model] database] putMessageBodyToDB:uid messageDate:messageDate data:data folderName:remoteFolderName];
                    }
                    
                    // TODO: do it asynchronously!
                    MCOMessageParser *parser = [MCOMessageParser messageParserWithData:data];
                    
                    [self loadMessageBody:uid threadId:threadId data:data parser:parser attachments:parser.attachments];
                    
                    if(!urgent) {
                        NSAssert(_nonUrgentfetchMessageBodyOpQueue.count > 0, @"no ops in the queue");
                        
                        FetchOpDesc *currentOp = nil;
                        for(NSUInteger i = 0; i < MAX_BODY_FETCH_OPS; i++) {
                            if(((FetchOpDesc*)_nonUrgentfetchMessageBodyOpQueue[i]).opId == opId) {
                                currentOp = _nonUrgentfetchMessageBodyOpQueue[i];
                                
                                [_nonUrgentfetchMessageBodyOpQueue removeObjectAtIndex:i];
                                break;
                            }
                        }
                        
                        NSAssert(currentOp != nil, @"cur op not found");
                        
                        SM_LOG_INFO(@"fetch op finished (message UID %u, folder '%@'), non-urgent body op count: %lu", uid, remoteFolderName, _nonUrgentfetchMessageBodyOpQueue.count);
                        
                        if(_nonUrgentfetchMessageBodyOpQueue.count > 0) {
                            FetchOpDesc *nextOp = _nonUrgentfetchMessageBodyOpQueue[0];
                            nextOp.op();
                        }
                    }
                }
                else {
                    SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (error code %ld)", uid, remoteFolderName, [error code]);
                    
                    MCOIMAPFetchContentOperation *op = [_fetchMessageBodyOps objectForKey:[NSNumber numberWithUnsignedInt:uid]];
                    
                    // TODO: bug! opBlock is always nil.
                    
                    // restart this message body fetch to prevent data loss
                    // on connectivity/server problems
                    [op start:opBlock];
                }
            };
            
            // TODO: don't fetch if body is already being fetched (non-urgently!)
            // TODO: if urgent fetch is requested, cancel the non-urgent fetch
            [op start:opBlock];
        };
        
        if(urgent) {
            fullOp();
        }
        else {
            [_nonUrgentfetchMessageBodyOpQueue addObject:[[FetchOpDesc alloc] initWithOpId:opId op:fullOp]];
            
            SM_LOG_INFO(@"new fetch op added (message UID %u, folder '%@'), non-urgent body op count: %lu", uid, remoteFolderName, _nonUrgentfetchMessageBodyOpQueue.count);
            
            if(_nonUrgentfetchMessageBodyOpQueue.count <= MAX_BODY_FETCH_OPS) {
                fullOp();
            }
        }
    }
}

- (void)loadMessageBody:(uint32_t)uid threadId:(uint64_t)threadId data:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    [[[appDelegate model] messageStorage] setMessageData:data parser:parser attachments:attachments uid:uid localFolder:_localFolder.localName threadId:threadId];
    
    [_localFolder increaseLocalFolderFootprint:data.length];
    
    NSDictionary *messageInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInteger:uid], [NSNumber numberWithUnsignedLongLong:threadId], nil] forKeys:[NSArray arrayWithObjects:@"UID", @"ThreadId", nil]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:messageInfo];
}

- (void)cancelBodyLoading:(uint32_t)uid {
    NSNumber *uidNum = [NSNumber numberWithUnsignedInt:uid];
    MCOIMAPFetchContentOperation *bodyFetchOp = [_fetchMessageBodyOps objectForKey:uidNum];
    
    if(bodyFetchOp) {
        [bodyFetchOp cancel];
        [_fetchMessageBodyOps removeObjectForKey:uidNum];
    }
    
    // TODO: remove it from _nonUrgentfetchMessageBodyOpQueue
}

- (void)stopBodiesLoading {
    for(NSNumber *uid in _fetchMessageBodyOps) {
        [[_fetchMessageBodyOps objectForKey:uid] cancel];
    }
    
    [_fetchMessageBodyOps removeAllObjects];
    
    [_nonUrgentfetchMessageBodyOpQueue removeAllObjects];
}

@end
