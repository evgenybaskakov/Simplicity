//
//  SMAbstractMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessageThread;

@protocol SMAbstractMessageStorage

@property (readonly) NSUInteger messageThreadsCount;

- (BOOL)addMessage:(SMMessage*)message updateDatabase:(Boolean)updateDatabase;
- (void)removeMessage:(SMMessage*)message updateDatabase:(Boolean)updateDatabase;

// TODO: use folder name along with UID!!! See https://github.com/evgenybaskakov/Simplicity/issues/20.
// TODO: return SMMessageThread*
- (NSNumber*)messageThreadByMessageUID:(uint32_t)uid;

- (SMMessageThread*)messageThreadById:(uint64_t)threadId;
- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index;
- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread;
- (void)deleteMessageThreads:(NSArray*)messageThreads updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (Boolean)deleteMessageFromStorage:(uint32_t)uid threadId:(uint64_t)threadId remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (void)deleteMessagesFromStorageByUIDs:(NSArray*)messageUIDs;

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview uid:(uint32_t)uid threadId:(uint64_t)threadId;
- (BOOL)messageHasData:(uint32_t)uid threadId:(uint64_t)threadId;

@end
