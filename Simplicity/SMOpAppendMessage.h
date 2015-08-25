//
//  SMOpAppendMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@class MCOMessageBuilder;

@interface SMOpAppendMessage : SMOperation

- (id)initWithMessage:(MCOMessageBuilder*)message remoteFolderName:(NSString*)remoteFolderName flags:(MCOMessageFlag)flags;

@end
