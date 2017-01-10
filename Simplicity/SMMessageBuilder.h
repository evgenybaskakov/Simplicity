//
//  SMMessageBuilder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/27/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOMessageBuilder;

@class SMAddress;
@class SMUserAccount;
@class SMAttachmentItem;

@interface SMMessageBuilder : NSObject<NSCoding>

@property (readonly) SMUserAccount *account;
@property (readonly) MCOMessageBuilder *mcoMessageBuilder;
@property (readonly) BOOL plainText;
@property (readonly) NSArray *attachments;
@property (readonly) NSArray *inlineAttachments;
@property (readonly) NSDate *creationDate;
@property (readonly) uint32_t uid;
@property (readonly) uint64_t threadId;

- (id)initWithMessageText:(NSString*)messageText plainText:(BOOL)plainText subject:(NSString*)subject from:(SMAddress*)from to:(NSArray<SMAddress*>*)to cc:(NSArray<SMAddress*>*)cc bcc:(NSArray<SMAddress*>*)bcc attachmentItems:(NSArray<SMAttachmentItem*>*)attachmentItems inlineAttachmentItems:(NSArray<SMAttachmentItem*>*)inlineAttachmentItems account:(SMUserAccount*)account;

@end
