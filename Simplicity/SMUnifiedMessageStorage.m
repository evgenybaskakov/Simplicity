//
//  SMUnifiedMessageStorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessage.h"
#import "SMMessageStorage.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMessageStorage.h"

@implementation SMUnifiedMessageStorage {
    NSMutableArray<SMMessageStorage*> *_attachedMessageStorages;
}

- (id)initWithUserAccount:(SMUnifiedAccount *)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _attachedMessageStorages = [NSMutableArray array];
        // nothing yet
    }
    
    return self;
}

- (void)attachMessageStorage:(SMMessageStorage*)messageStorage {
    NSAssert([_attachedMessageStorages indexOfObject:messageStorage] == NSNotFound, @"messageStorage already attached");
    
    [_attachedMessageStorages addObject:messageStorage];
    
    // TODO: Refresh message storage
}

- (void)detachMessageStorage:(SMMessageStorage*)localFolder {
    // TODO!!! Issue #97.
}

- (void)refreshUnifiedMessageStorage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        
        // Merge
        
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
        });
    });
}

- (BOOL)addMessage:(SMMessage*)message toLocalFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase {
    SM_FATAL(@"TODO");
    return NO;
}

- (void)removeMessage:(SMMessage*)message fromLocalFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase {
    SM_FATAL(@"TODO");
}

- (NSNumber*)messageThreadByMessageUID:(uint32_t)uid {
    SM_FATAL(@"TODO");
    return nil;
}

- (SMMessageThread*)messageThreadById:(uint64_t)threadId localFolder:(NSString*)folder {
    SM_FATAL(@"TODO");
    return nil;
}

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index localFolder:(NSString*)folder {
    SM_FATAL(@"TODO");
    return nil;
}

- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread localFolder:(NSString*)localFolder {
    SM_FATAL(@"TODO");
    return 0;
}

- (void)deleteMessageThreads:(NSArray*)messageThreads fromLocalFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    SM_FATAL(@"TODO");
}

- (Boolean)deleteMessageFromStorage:(uint32_t)uid threadId:(uint64_t)threadId localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    SM_FATAL(@"TODO");
    return NO;
}

- (void)deleteMessagesFromStorageByUIDs:(NSArray*)messageUIDs {
    SM_FATAL(@"TODO");
}

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview uid:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
    SM_FATAL(@"TODO");
    return nil;
}

- (BOOL)messageHasData:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
    SM_FATAL(@"TODO");
    return NO;
}

- (NSUInteger)messageThreadsCount {
    return 0; // TODO
}

@end
