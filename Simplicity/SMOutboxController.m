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
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessage.h"
#import "SMMessageBuilder.h"
#import "SMOutgoingMessage.h"
#import "SMOutboxController.h"

@implementation SMOutboxController

+ (NSString*)outboxFolderName {
    return @"Outbox";
}

- (void)sendMessage:(SMMessageBuilder*)messageBuilder postSendActionTarget:(id)target postSendActionSelector:(SEL)selector {
    SM_LOG_DEBUG(@"Sending message");
    
    SMOutgoingMessage *outgoingMessage = [[SMOutgoingMessage alloc] initWithMessageBuilder:messageBuilder];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate model] localFolderRegistry];
    
    SMLocalFolder *outboxFolder = [localFolderRegistry getLocalFolder:@"Outbox"]; // TODO!!!
    [outboxFolder addMessage:outgoingMessage];

    SMOpSendMessage *op = [[SMOpSendMessage alloc] initWithOutgoingMessage:outgoingMessage];

    op.postActionTarget = target;
    op.postActionSelector = selector;

    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
}

@end
