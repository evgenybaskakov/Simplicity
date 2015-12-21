//
//  SMOutgoingMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMMessage.h"

@class SMMessageBuilder;

@interface SMOutgoingMessage : SMMessage

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder;

@end
