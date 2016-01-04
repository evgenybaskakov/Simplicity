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
#import "SMOperationQueue.h"
#import "SMOpSendMessage.h"
#import "SMOutgoingMessage.h"
#import "SMOutboxController.h"

@implementation SMOutboxController

+ (NSString*)outboxFolderName {
    return @"Outbox";
}

- (id)init {
    self = [super init];
    
    if(self) {
        
    }
    
    return self;
}

- (void)loadSMTPQueue:(SMOperationQueue*)queue postSendActionTarget:(id)target postSendActionSelector:(SEL)selector {
    for(NSUInteger i = 0, n = queue.count; i < n; i++) {
        SMOperation *op = [queue getOpAtIndex:i];
        
        if([op isKindOfClass:[SMOpSendMessage class]]) {
            SMOpSendMessage *opSendMessage = (SMOpSendMessage*)op;

            opSendMessage.postActionTarget = target;
            opSendMessage.postActionSelector = selector;

            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            SMFolder *outboxFolder = [[[appDelegate model] mailbox] outboxFolder];
            SMLocalFolder *outboxLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:outboxFolder.fullName];

            NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
            [outboxLocalFolder addMessage:opSendMessage.outgoingMessage];
        }
    }
}

- (void)sendMessage:(SMOutgoingMessage*)outgoingMessage postSendActionTarget:(id)target postSendActionSelector:(SEL)selector {
    SM_LOG_DEBUG(@"Sending message");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *outboxFolder = [[[appDelegate model] mailbox] outboxFolder];
    SMLocalFolder *outboxLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:outboxFolder.fullName];

    NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
    [outboxLocalFolder addMessage:outgoingMessage];

    SMOpSendMessage *op = [[SMOpSendMessage alloc] initWithOutgoingMessage:outgoingMessage];

    op.postActionTarget = target;
    op.postActionSelector = selector;

    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
    [[[appDelegate appController] operationExecutor] saveSMTPQueue];
}

- (void)finishMessageSending:(SMOutgoingMessage*)message {
    SM_LOG_DEBUG(@"Removing message");

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *outboxFolder = [[[appDelegate model] mailbox] outboxFolder];
    SMLocalFolder *outboxLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:outboxFolder.fullName];

    NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
    [outboxLocalFolder removeMessage:message];

    [[[appDelegate appController] operationExecutor] saveSMTPQueue];
}

- (void)cancelMessageSending:(SMOutgoingMessage*)message {
    SM_LOG_DEBUG(@"Cancel message sending");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *outboxFolder = [[[appDelegate model] mailbox] outboxFolder];
    SMLocalFolder *outboxLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:outboxFolder.fullName];
    
    NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
    [outboxLocalFolder removeMessage:message];

    [[[[appDelegate appController] operationExecutor] smtpQueue] cancelSendOpWithMessage:message];
    [[[appDelegate appController] operationExecutor] saveSMTPQueue];
}

@end
