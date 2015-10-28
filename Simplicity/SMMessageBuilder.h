//
//  SMMessageBuilder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/27/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOMessageBuilder;

@interface SMMessageBuilder : NSObject

+ (MCOMessageBuilder*)createMessage:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc fromMailbox:(NSString*)fromMailbox attachmentItems:(NSArray*)attachmentItems;
+ (NSData*)serializeMessage:(MCOMessageBuilder*)messageBuilder;
+ (MCOMessageBuilder*)deserializeMessage:(NSData*)data;

@end
