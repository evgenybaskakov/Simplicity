//
//  SMOutboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMOpSendMessage;
@class SMOperationQueue;
@class SMOutgoingMessage;

@interface SMOutboxController : SMUserAccountDataObject

+ (NSString*)outboxFolderName;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)loadSMTPQueue:(SMOperationQueue*)queue postSendAction:(void (^)(SMOpSendMessage *))postSendAction;
- (BOOL)sendMessage:(SMOutgoingMessage*)message postSendAction:(void (^)(SMOpSendMessage *))postSendAction;
- (void)finishMessageSending:(SMOutgoingMessage*)message;
- (void)cancelMessageSending:(SMOutgoingMessage*)message;

@end
