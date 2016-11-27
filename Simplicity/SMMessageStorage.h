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
@protocol SMAbstractLocalFolder;

@class SMMessage;
@class SMMessageThread;
@class SMUnifiedMessageStorage;

@interface SMMessageStorage : SMUserAccountDataObject<SMAbstractMessageStorage>

typedef NS_ENUM(NSInteger, SMMessageStorageUpdateResult) {
    SMMesssageStorageUpdateResultNone,
    SMMesssageStorageUpdateResultFlagsChanged,
    SMMesssageStorageUpdateResultStructureChanged
};

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolder:(id<SMAbstractLocalFolder>)localFolder;

- (void)attachToUnifiedMessageStorage:(SMUnifiedMessageStorage*)unifiedMessageStorage;
- (void)deattachFromUnifiedMessageStorage;

- (void)startUpdate;
- (void)cancelUpdate;

- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount newMessages:(NSMutableArray<MCOIMAPMessage*>*)newMessages;
- (void)markMessageThreadAsUpdated:(uint64_t)threadId;
- (SMMessageStorageUpdateResult)endUpdateWithRemoteFolder:(NSString*)remoteFolder removeVanishedMessages:(BOOL)removeVanishedMessages updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount processNewUnseenMessagesBlock:(void (^)(NSArray *newMessages))processNewUnseenMessagesBlock;

- (BOOL)addMessageToStorage:(SMMessage*)message updateDatabase:(BOOL)updateDatabase;
- (void)removeMessageFromStorage:(SMMessage*)message updateDatabase:(BOOL)updateDatabase;
- (void)updateMessageInStorage:(SMMessage*)message;

- (void)deleteMessagesFromStorageByMessageIds:(NSArray<NSNumber*>*)messageIds;
- (void)deleteMessageThread:(SMMessageThread*)messageThread updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount;
- (BOOL)deleteMessageFromStorage:(uint64_t)messageId threadId:(uint64_t)threadId remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount;

// TODO: use folder name along with UID!!! See https://github.com/evgenybaskakov/Simplicity/issues/20.
// TODO: return SMMessageThread*
- (NSNumber*)messageThreadByMessageId:(uint64_t)messageId;
- (SMMessageThread*)messageThreadById:(uint64_t)threadId;

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody messageId:(uint64_t)messageId threadId:(uint64_t)threadId;
- (BOOL)messageHasData:(uint64_t)messageId threadId:(uint64_t)threadId;

@end
