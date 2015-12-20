//
//  SMOutboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessageBuilder;

@interface SMOutboxController : NSObject

+ (NSString*)outboxFolderName;

- (void)sendMessage:(SMMessageBuilder*)message postSendActionTarget:(id)target postSendActionSelector:(SEL)selector;

@end
