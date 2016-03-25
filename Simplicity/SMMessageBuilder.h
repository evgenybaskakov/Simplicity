//
//  SMMessageBuilder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/27/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOAddress;
@class MCOMessageBuilder;

@class SMUserAccount;

@interface SMMessageBuilder : NSObject<NSCoding>

@property (readonly) SMUserAccount *account;
@property (readonly) MCOMessageBuilder *mcoMessageBuilder;
@property (readonly) NSArray *attachments;
@property (readonly) NSDate *creationDate;
@property (readonly) uint32_t uid;
@property (readonly) uint64_t threadId;

- (id)initWithMessageText:(NSString*)messageText subject:(NSString*)subject from:(MCOAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc attachmentItems:(NSArray*)attachmentItems account:(SMUserAccount*)account;

@end
