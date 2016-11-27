//
//  SMOutboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMUserAccount.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOpSendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMAccountMailbox.h"
#import "SMFolder.h"
#import "SMAbstractLocalFolder.h"
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

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        
    }
    
    return self;
}

- (void)loadSMTPQueue:(SMOperationQueue*)queue postSendAction:(void (^)(SMOpSendMessage *))postSendAction {
    for(NSUInteger i = 0, n = queue.count; i < n; i++) {
        SMOperation *op = [queue getOpAtIndex:i];
        
        if([op isKindOfClass:[SMOpSendMessage class]]) {
            SMOpSendMessage *opSendMessage = (SMOpSendMessage*)op;

            opSendMessage.postAction = (void (^)(SMOperation*))postSendAction;

            SMFolder *outboxFolder = [[_account mailbox] outboxFolder];
            id<SMAbstractLocalFolder> outboxLocalFolder = [[_account localFolderRegistry] getLocalFolderByName:outboxFolder.fullName];

            NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
            [outboxLocalFolder addMessage:opSendMessage.outgoingMessage];
        }
    }
}

- (BOOL)sendMessage:(SMOutgoingMessage*)outgoingMessage postSendAction:(void (^)(SMOpSendMessage *))postSendAction {
    SM_LOG_DEBUG(@"Sending message");
    
    SMFolder *outboxFolder = [[_account mailbox] outboxFolder];
    id<SMAbstractLocalFolder> outboxLocalFolder = [[_account localFolderRegistry] getLocalFolderByName:outboxFolder.fullName];

    if(!outboxLocalFolder) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Dismiss"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot send message, because the Outbox folder is not availble for account '%@'.", _account.accountName]];
        [alert setInformativeText:@"Check account settings or choose another account to send the message in the 'From' field."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return FALSE;
    }

    [outboxLocalFolder addMessage:outgoingMessage];

    SMOpSendMessage *op = [[SMOpSendMessage alloc] initWithOutgoingMessage:outgoingMessage operationExecutor:[(SMUserAccount*)_account operationExecutor]];

    op.postAction = (void (^)(SMOperation*))postSendAction;

    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    [[(SMUserAccount*)_account operationExecutor] saveSMTPQueue];
    
    return TRUE;
}

- (void)finishMessageSending:(SMOutgoingMessage*)message {
    SM_LOG_DEBUG(@"Removing message");

    SMFolder *outboxFolder = [[_account mailbox] outboxFolder];
    id<SMAbstractLocalFolder> outboxLocalFolder = [[_account localFolderRegistry] getLocalFolderByName:outboxFolder.fullName];

    NSAssert(outboxLocalFolder != nil, @"outboxLocalFolder is nil");
    [outboxLocalFolder removeMessage:message];

    [[(SMUserAccount*)_account operationExecutor] saveSMTPQueue];
}

- (void)cancelMessageSending:(SMOutgoingMessage*)message {
    SM_LOG_DEBUG(@"Cancel message sending");

    [[[(SMUserAccount*)_account operationExecutor] smtpQueue] cancelSendOpWithMessage:message];
    [[(SMUserAccount*)_account operationExecutor] saveSMTPQueue];
}

@end
