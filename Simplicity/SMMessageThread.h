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
@property (readonly) Boolean unseen;
@property (readonly) Boolean flagged;
@property (readonly) Boolean hasAttachments;
@property (readonly) Boolean hasDraft;
@property (readonly) NSOrderedSet *labels;

@property (readonly, nonatomic) SMUserAccount *account;

- (id)initWithThreadId:(uint64_t)threadId messageStorage:(SMMessageStorage*)messageStorage;

- (NSArray*)messagesSortedByDate;
- (SMMessage*)getMessageByUID:(uint32_t)uid; // TODO: this is not one-to-one correspondence, fix! (issue #110)

typedef NS_ENUM(NSInteger, SMThreadUpdateResult) {
    SMThreadUpdateResultNone,
    SMThreadUpdateResultFlagsChanged,
    SMThreadUpdateResultStructureChanged
};

- (SMThreadUpdateResult)addMessage:(SMMessage*)message;
- (SMThreadUpdateResult)removeMessage:(SMMessage*)message;

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage plainTextBody:(NSString*)plainTextBody hasAttachments:(BOOL)hasAttachments remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session unseenCount:(NSUInteger*)unseenCount messageIsNew:(BOOL*)messageIsNew;
- (SMThreadUpdateResult)endUpdate:(Boolean)removeVanishedMessages vanishedMessages:(NSMutableArray*)vanishedMessages addNewUnseenMessages:(NSMutableArray*)addNewUnseenMessages;
- (void)markAsUpdated;

- (void)cancelUpdate;

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody uid:(uint32_t)uid;
- (Boolean)messageHasData:(uint32_t)uid;
- (Boolean)updateThreadAttributesFromMessageUID:(uint32_t)uid;

- (void)removeMessageFromMessageThread:(uint32_t)uid;

@end
