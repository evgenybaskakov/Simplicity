//
//  SMOutboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOpSendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMMessageBuilder.h"
#import "SMOutboxController.h"

@implementation SMOutboxController

+ (NSString*)outboxFolderName {
    return @"Outbox";
}

- (void)sendMessage:(SMMessageBuilder*)messageBuilder postSendActionTarget:(id)target postSendActionSelector:(SEL)selector {
    SM_LOG_DEBUG(@"Sending message");
    
    SMOpSendMessage *op = [[SMOpSendMessage alloc] initWithMessageBuilder:messageBuilder];

    op.postActionTarget = target;
    op.postActionSelector = selector;

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
}

@end
