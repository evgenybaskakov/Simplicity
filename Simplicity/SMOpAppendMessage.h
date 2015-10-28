//
//  SMOpAppendMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@class SMMessageBuilder;

@interface SMOpAppendMessage : SMOperation

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder remoteFolderName:(NSString*)remoteFolderName flags:(MCOMessageFlag)flags;

@end
