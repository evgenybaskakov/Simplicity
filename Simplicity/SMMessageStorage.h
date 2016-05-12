//
//  SMMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractMessageStorage.h"

@protocol SMAbstractAccount;

@class SMMessage;
@class SMMessageThread;
@class SMUnifiedMessageStorage;

@interface SMMessageStorage : SMUserAccountDataObject<SMAbstractMessageStorage>

typedef NS_ENUM(NSInteger, SMMessageStorageUpdateResult) {
    SMMesssageStorageUpdateResultNone,
    SMMesssageStorageUpdateResultFlagsChanged,
    SMMesssageStorageUpdateResultStructureChanged
};

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolder:(NSString*)localFolder;

- (void)attachToUnifiedMessageStorage:(SMUnifiedMessageStorage*)unifiedMessageStorage;
- (void)deattachFromUnifiedMessageStorage;

- (void)startUpdate;
- (void)cancelUpdate;

- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (void)markMessageThreadAsUpdated:(uint64_t)threadId;
- (SMMessageStorageUpdateResult)endUpdateWithRemoteFolder:(NSString*)remoteFolder removeVanishedMessages:(Boolean)removeVanishedMessages updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount processNewUnseenMessagesBlock:(void (^)(NSArray *newMessages))processNewUnseenMessagesBlock;

- (BOOL)addMessageToStorage:(SMMessage*)message updateDatabase:(Boolean)updateDatabase;
- (void)removeMessageFromStorage:(SMMessage*)message updateDatabase:(Boolean)updateDatabase;

- (void)deleteMessagesFromStorageByUIDs:(NSArray*)messageUIDs;
- (void)deleteMessageThreads:(NSArray*)messageThreads updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (Boolean)deleteMessageFromStorage:(uint32_t)uid threadId:(uint64_t)threadId remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount;

// TODO: use folder name along with UID!!! See https://github.com/evgenybaskakov/Simplicity/issues/20.
// TODO: return SMMessageThread*
- (NSNumber*)messageThreadByMessageUID:(uint32_t)uid;
- (SMMessageThread*)messageThreadById:(uint64_t)threadId;

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview uid:(uint32_t)uid threadId:(uint64_t)threadId;

- (BOOL)messageHasData:(uint32_t)uid threadId:(uint64_t)threadId;

@end
