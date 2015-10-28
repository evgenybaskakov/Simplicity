//
//  SMMessageBuilder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/27/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOMessageBuilder;

@interface SMMessageBuilder : NSObject<NSCoding>

@property (readonly) MCOMessageBuilder *mcoMessageBuilder;
@property (readonly) NSArray *attachments;

- (id)initWithMessageText:(NSString*)messageText subject:(NSString*)subject from:(MCOAddress*)from to:(MCOAddress*)to cc:(MCOAddress*)cc bcc:(MCOAddress*)bcc attachmentItems:(NSArray*)attachmentItems;
- (id)initWithMCOMessageBuilder:(MCOMessageBuilder*)mcoMessageBuilder attachments:(NSArray*)attachments;

@end
