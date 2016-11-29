//
//  SMMessageThread.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>

@class MCOIMAPMessage;
@class MCOIMAPSession;

@class SMUserAccount;
@class SMMessageStorage;
@class SMMessage;

@interface SMMessageThread : NSObject

@property (readonly) __weak SMMessageStorage *messageStorage;

@property (readonly) uint64_t threadId;
@property (readonly) NSInteger messagesCount;
@property (readonly) NSInteger unseenMessagesCount;
@property (readonly) BOOL unseen;
@property (readonly) BOOL flagged;
@property (readonly) BOOL hasAttachments;
@property (readonly) BOOL hasDraft;
@property (readonly) NSOrderedSet *labels;

@property (readonly, nonatomic) SMUserAccount *account;

- (id)initWithThreadId:(uint64_t)threadId messageStorage:(SMMessageStorage*)messageStorage;

- (NSArray*)messagesSortedByDate;
- (SMMessage*)getMessageByMessageId:(uint64_t)messageId;

typedef NS_ENUM(NSInteger, SMThreadUpdateResult) {
    SMThreadUpdateResultNone,
    SMThreadUpdateResultFlagsChanged,
    SMThreadUpdateResultStructureChanged
};

- (SMThreadUpdateResult)addMessage:(SMMessage*)message;
- (SMThreadUpdateResult)removeMessage:(SMMessage*)message;

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage ignoreUpdate:(BOOL)ignoreUpdate plainTextBody:(NSString*)plainTextBody hasAttachments:(BOOL)hasAttachments remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session unseenCount:(NSUInteger*)unseenCount messageIsNew:(BOOL*)messageIsNew;
- (SMThreadUpdateResult)endUpdateWithRemoteFolder:(NSString*)remoteFolder removeVanishedMessages:(BOOL)removeVanishedMessages vanishedMessages:(NSMutableArray*)vanishedMessages addNewUnseenMessages:(NSMutableArray*)addNewUnseenMessages;
- (void)markAsUpdated;

- (void)cancelUpdate;

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody messageId:(uint64_t)messageId;
- (BOOL)messageHasData:(uint64_t)messageId;
- (BOOL)updateThreadAttributesForMessageId:(uint64_t)messageId;
- (void)removeMessageFromMessageThread:(uint64_t)messageId;

- (void)addLabel:(NSString*)label;
- (void)removeLabel:(NSString*)label;

@end
