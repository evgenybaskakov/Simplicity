//
//  SMOpSendMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@class SMMessageBuilder;

@interface SMOpSendMessage : SMOperation

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder;

@end
