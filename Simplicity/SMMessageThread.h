//
//  SMMessageThread.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOIMAPMessage;
@class MCOIMAPSession;
@class SMMessage;

@interface SMMessageThread : NSObject

@property (readonly) uint64_t threadId;
@property (readonly) NSInteger messagesCount;
@property (readonly) Boolean unseen;
@property (readonly) Boolean flagged;
@property (readonly) Boolean hasAttachments;
@property (readonly) NSOrderedSet *labels;

- (id)initWithThreadId:(uint64_t)threadId;

- (NSArray*)messagesSortedByDate;
- (SMMessage*)getMessage:(uint32_t)uid;

typedef NS_ENUM(NSInteger, SMThreadUpdateResult) {
	SMThreadUpdateResultNone,
	SMThreadUpdateResultFlagsChanged,
	SMThreadUpdateResultStructureChanged
};

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session;
- (SMThreadUpdateResult)endUpdate:(Boolean)removeVanishedMessages vanishedMessages:(NSMutableArray*)vanishedMessages;
- (void)markAsUpdated;

- (void)cancelUpdate;

- (void)setMessageData:(NSData*)data uid:(uint32_t)uid;
- (Boolean)messageHasData:(uint32_t)uid;
- (Boolean)updateThreadAttributesFromMessageUID:(uint32_t)uid;

- (void)removeMessageFromMessageThread:(uint32_t)uid;

@end
