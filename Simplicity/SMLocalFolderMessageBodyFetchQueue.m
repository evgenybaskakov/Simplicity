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
#import "SMFolderUIDDictionary.h"
#import "SMMessageStorage.h"
#import "SMDatabase.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderMessageBodyFetchQueue.h"

static const NSUInteger MAX_BODY_FETCH_OPS = 3;

@interface FetchOpDesc : NSObject
@property (readonly) void (^op)();
@property (readonly) uint32_t uid;
@property (readonly) NSString *folderName;
- (id)initWithUID:(uint32_t)uid folderName:(NSString*)folderName op:(void (^)())op;
@end

@implementation FetchOpDesc
- (id)initWithUID:(uint32_t)uid folderName:(NSString*)folderName op:(void (^)())op {
    self = [super init];
    if(self) {
        _uid = uid;
        _folderName = folderName;
        _op = op;
    }
    return self;
}
@end

@implementation SMLocalFolderMessageBodyFetchQueue {
    SMLocalFolder *__weak _localFolder;
    SMFolderUIDDictionary *_fetchMessageBodyOps;
    NSMutableArray *_nonUrgentfetchMessageBodyOpQueue;
    NSUInteger _nextFetchOpId;
}

- (id)initWithLocalFolder:(SMLocalFolder*)localFolder {
    self = [super init];
    
    if(self) {
        _localFolder = localFolder;
        _fetchMessageBodyOps = [[SMFolderUIDDictionary alloc] init];
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
        
        void (^fullOp)() = ^{
            FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
            if(currentOpDesc == nil) {
                SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                return;
            }
            
            MCOIMAPSession *session = [[appDelegate model] imapSession];
            NSAssert(session, @"session is nil");
            
            MCOIMAPFetchContentOperation *op = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
            op.urgent = urgent;
            
            [op start:^(NSError * error, NSData * data) {
                FetchOpDesc *currentOpDesc = (FetchOpDesc*)[_fetchMessageBodyOps objectForUID:uid folder:remoteFolderName];
                if(currentOpDesc == nil) {
                    SM_LOG_INFO(@"Downloading body for message UID %u from folder '%@' skipped (completed before or cancelled)", uid, remoteFolderName);
                    return;
                }

                if(error == nil || [error code] == MCOErrorNone) {
                    [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolderName];
                    
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
                        
                        [_nonUrgentfetchMessageBodyOpQueue removeObject:currentOpDesc];
                        
                        SM_LOG_INFO(@"fetch op finished (message UID %u, folder '%@'), non-urgent body op count: %lu", uid, remoteFolderName, _nonUrgentfetchMessageBodyOpQueue.count);
                        
                        while(_nonUrgentfetchMessageBodyOpQueue.count > 0) {
                            FetchOpDesc *nextOp = _nonUrgentfetchMessageBodyOpQueue[0];
                            
                            // skip all completed/urgent/cancelled ops
                            if([_fetchMessageBodyOps objectForUID:nextOp.uid folder:nextOp.folderName] != nil) {
                                nextOp.op();
                                break;
                            }
                            else {
                                [_nonUrgentfetchMessageBodyOpQueue removeObjectAtIndex:0];
                            }
                        }
                    }
                }
                else {
                    SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@ (error code %ld); trying again...", uid, remoteFolderName, error.code);

                    currentOpDesc.op();
                }
            }];
        };
        
        FetchOpDesc *desc = [[FetchOpDesc alloc] initWithUID:uid folderName:remoteFolderName op:fullOp];
        
        [_fetchMessageBodyOps setObject:desc forUID:uid folder:remoteFolderName];

        if(urgent) {
            fullOp();
        }
        else {
            [_nonUrgentfetchMessageBodyOpQueue addObject:desc];
            
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

- (void)cancelBodyLoading:(uint32_t)uid remoteFolder:(NSString*)remoteFolder {
    [_fetchMessageBodyOps removeObjectforUID:uid folder:remoteFolder];
}

- (void)stopBodiesLoading {
    [_fetchMessageBodyOps removeAllObjects];
    [_nonUrgentfetchMessageBodyOpQueue removeAllObjects];
}

@end
