//
//  SMMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@class SMMessage;
@class SMMessageComparators;
@class SMMessageThread;

@interface SMMessageStorage : NSObject

@property (readonly) SMMessageComparators *comparators;

- (void)ensureLocalFolderExists:(NSString*)localFolder;
- (void)removeLocalFolder:(NSString*)localFolder;

- (NSUInteger)messageThreadsCountInLocalFolder:(NSString*)localFolder;

typedef NS_ENUM(NSInteger, SMMessageStorageUpdateResult) {
	SMMesssageStorageUpdateResultNone,
	SMMesssageStorageUpdateResultFlagsChanged,
	SMMesssageStorageUpdateResultStructureChanged
};

- (void)startUpdate:(NSString*)folder;
- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session updateDatabase:(Boolean)updateDatabase;
- (void)markMessageThreadAsUpdated:(uint64_t)threadId localFolder:(NSString*)localFolder;
- (SMMessageStorageUpdateResult)endUpdate:(NSString*)localFolder removeFolder:(NSString*)remoteFolder removeVanishedMessages:(Boolean)removeVanishedMessages updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (void)cancelUpdate:(NSString*)localFolder;

// TODO: use folder name along with UID!!! See https://github.com/evgenybaskakov/Simplicity/issues/20.
// TODO: return SMMessageThread*
- (NSNumber*)messageThreadByMessageUID:(uint32_t)uid;

- (SMMessageThread*)messageThreadById:(uint64_t)threadId localFolder:(NSString*)folder;
- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index localFolder:(NSString*)folder;
- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread localFolder:(NSString*)localFolder;
- (void)deleteMessageThreads:(NSArray*)messageThreads fromLocalFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolder updateDatabase:(Boolean)updateDatabase;
- (Boolean)deleteMessageFromStorage:(uint32_t)uid threadId:(uint64_t)threadId localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolder;
- (void)deleteMessagesFromStorageByUIDs:(NSArray*)messageUIDs;

- (void)setMessageData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments uid:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId;
- (BOOL)messageHasData:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId;

@end
