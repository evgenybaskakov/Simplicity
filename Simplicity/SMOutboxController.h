//
//  SMOutboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMOperationQueue;
@class SMOutgoingMessage;

@interface SMOutboxController : SMUserAccountDataObject

+ (NSString*)outboxFolderName;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)loadSMTPQueue:(SMOperationQueue*)queue postSendActionTarget:(id)target postSendActionSelector:(SEL)selector;
- (BOOL)sendMessage:(SMOutgoingMessage*)message postSendActionTarget:(id)target postSendActionSelector:(SEL)selector;
- (void)finishMessageSending:(SMOutgoingMessage*)message;
- (void)cancelMessageSending:(SMOutgoingMessage*)message;

@end
