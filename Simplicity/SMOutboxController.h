//
//  SMOutboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperationQueue;
@class SMOutgoingMessage;

@interface SMOutboxController : NSObject

+ (NSString*)outboxFolderName;

- (void)loadSMTPQueue:(SMOperationQueue*)queue postSendActionTarget:(id)target postSendActionSelector:(SEL)selector;
- (void)sendMessage:(SMOutgoingMessage*)message postSendActionTarget:(id)target postSendActionSelector:(SEL)selector;
- (void)finishMessageSending:(SMOutgoingMessage*)message;
- (void)cancelMessageSending:(SMOutgoingMessage*)message;

@end
