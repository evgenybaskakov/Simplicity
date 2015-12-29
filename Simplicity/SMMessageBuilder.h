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

@interface SMMessageBuilder : NSObject<NSCoding>

@property (readonly) MCOMessageBuilder *mcoMessageBuilder;
@property (readonly) NSArray *attachments;
@property (readonly) NSDate *creationDate;

- (id)initWithMessageText:(NSString*)messageText subject:(NSString*)subject from:(MCOAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc attachmentItems:(NSArray*)attachmentItems;

@end
