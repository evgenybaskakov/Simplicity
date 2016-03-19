//
//  SMMessageEditorController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMOperationExecutor.h"
#import "SMOpAppendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMUserAccount.h"
#import "SMMessageBuilder.h"
#import "SMMailbox.h"
#import "SMAddress.h"
#import "SMFolder.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMOutboxController.h"
#import "SMAttachmentItem.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageThread.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageEditorController.h"

// TODO: See issue #79. The editor should use not the current account, but allow the user to choose it.
//       Also it should decide what account is to use by default when replying / forwarding.

@implementation SMMessageEditorController {
    NSMutableArray *_attachmentItems;
    MCOMessageBuilder *_saveDraftMessage;
    SMOpAppendMessage *_saveDraftOp;
    MCOMessageBuilder *_prevSaveDraftMessage;
    SMOpAppendMessage *_prevSaveDraftOp;
    uint32_t _saveDraftUID;
    Boolean _shouldDeleteSavedDraft;
}

- (id)initWithDraftUID:(uint32_t)draftMessageUid {
    self = [super init];
    
    if(self) {
        _attachmentItems = [NSMutableArray array];
        _saveDraftUID = draftMessageUid;
    }
    
    return self;
}

#pragma mark Attachment management

- (void)addAttachmentItem:(SMAttachmentItem*)attachmentItem {
    [_attachmentItems addObject:attachmentItem];
}

- (void)removeAttachmentItems:(NSArray*)attachmentItems {
    [_attachmentItems removeObjectsInArray:attachmentItems];
}

#pragma mark Actions

- (void)sendMessage:(NSString*)messageText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    SMMessageBuilder *messageBuilder = [[SMMessageBuilder alloc] initWithMessageText:messageText subject:subject from:[MCOAddress addressWithDisplayName:[[appDelegate preferencesController] smtpUserName:appDelegate.currentAccountIdx] mailbox:[[appDelegate preferencesController] smtpUserName:appDelegate.currentAccountIdx]] to:[SMAddress addressListToMCOAddresses:to] cc:[SMAddress addressListToMCOAddresses:cc] bcc:[SMAddress addressListToMCOAddresses:bcc] attachmentItems:_attachmentItems];

    SM_LOG_DEBUG(@"'%@'", messageBuilder.mcoMessageBuilder);
    
    SMOutgoingMessage *outgoingMessage = [[SMOutgoingMessage alloc] initWithMessageBuilder:messageBuilder ];
    
    [[appDelegate.currentAccount outboxController] sendMessage:outgoingMessage postSendActionTarget:self postSendActionSelector:@selector(messageSentByServer:)];
}

- (void)messageSentByServer:(SMOutgoingMessage*)message {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate.currentAccount outboxController] finishMessageSending:message];
    
    [self deleteSavedDraft];

    if(_saveDraftOp) {
        if(![_saveDraftOp cancelOp]) {
            // Could not cancel save op. To avoid orphaned drafts,
            // schedule its deletion for later.
            _shouldDeleteSavedDraft = YES;
        }
    }
}

- (void)saveDraft:(NSString*)messageText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc {
    NSAssert(!_shouldDeleteSavedDraft, @"_shouldDeleteSavedDraft is set (which means that message was already sent and no more savings allowed)");
    
    if(_saveDraftOp) {
        // There may be two last operations: the current one and a previous one
        // We're trying to cancel the current one. If that's successful, we'll simply replace it later.
        // Otherwise, it is in progress, so there shouldn't be any previous one.
        if(![_saveDraftOp cancelOp]) {
            _prevSaveDraftOp = _saveDraftOp;
            _prevSaveDraftMessage = _saveDraftMessage;
        }
        
        _saveDraftMessage = nil;
        _saveDraftOp = nil;
    }

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SMMessageBuilder *messageBuilder = [[SMMessageBuilder alloc] initWithMessageText:messageText subject:subject from:[MCOAddress addressWithDisplayName:[[appDelegate preferencesController] smtpUserName:appDelegate.currentAccountIdx] mailbox:[[appDelegate preferencesController] smtpUserName:appDelegate.currentAccountIdx]] to:[SMAddress addressListToMCOAddresses:to] cc:[SMAddress addressListToMCOAddresses:cc] bcc:[SMAddress addressListToMCOAddresses:bcc] attachmentItems:_attachmentItems];
    
    SM_LOG_DEBUG(@"'%@'", messageBuilder.mcoMessageBuilder);
    
    SMFolder *draftsFolder = [[appDelegate.currentAccount mailbox] draftsFolder];
    NSAssert(draftsFolder && draftsFolder.fullName, @"no drafts folder");
    
    SMOpAppendMessage *op = [[SMOpAppendMessage alloc] initWithMessageBuilder:messageBuilder remoteFolderName:draftsFolder.fullName flags:(MCOMessageFlagSeen | MCOMessageFlagDraft) operationExecutor:[appDelegate.currentAccount operationExecutor]];
    
    op.postActionTarget = self;
    op.postActionSelector = @selector(messageSavedToDrafts:);
    
    [[appDelegate.currentAccount operationExecutor] enqueueOperation:op];
    
    _saveDraftMessage = messageBuilder.mcoMessageBuilder;
    _saveDraftOp = op;
    
    _hasUnsavedAttachments = NO;
}

#pragma mark Message after-saving actions

- (void)messageSavedToDrafts:(NSDictionary *)info {
    MCOMessageBuilder *message = [info objectForKey:@"Message"]; // TODO: use SMMessage, not builder
    uint32_t uid = [[info objectForKey:@"UID"] unsignedIntValue];
    
    SM_LOG_DEBUG(@"uid %u", uid);
    
    if(message == _prevSaveDraftMessage || message == _saveDraftMessage) {
        [self deleteSavedDraft];
        
        if(message == _prevSaveDraftMessage) {
            _prevSaveDraftMessage = nil;
            _prevSaveDraftOp = nil;
        } else {
            _saveDraftMessage = nil;
            _saveDraftOp = nil;
        }
    
        NSAssert(_saveDraftUID == 0, @"bad _saveDraftUID %u, expected zero", _saveDraftUID);
        _saveDraftUID = uid;

        if(_shouldDeleteSavedDraft) {
            // This may happen if, most commonly, while the draft was being saved,
            // the message writing was finished and the message was sent.
            // So the draft that's been just saved suddenly became unneeded.
            // Hence, just delete it right away.
            [self deleteSavedDraft];
        }
    }
}

- (Boolean)hasSavedDraft {
    return (_saveDraftUID != 0);
}

- (void)deleteSavedDraft {
    if(_saveDraftUID == 0) {
        SM_LOG_DEBUG(@"No saved message draft");
        return;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSAssert(appDelegate != nil, @"no appDelegate");
    
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    NSAssert(mailbox != nil, @"no mailbox");
    
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    SMFolder *draftsFolder = [[appDelegate.currentAccount mailbox] draftsFolder];
    NSAssert(draftsFolder && draftsFolder.fullName, @"no drafts folder");
    
    SMLocalFolder *draftsLocalFolder = [[appDelegate.currentAccount localFolderRegistry] getLocalFolder:draftsFolder.fullName];
    NSAssert(draftsLocalFolder != nil, @"no local drafts folder");
    
    SMMessageListViewController *messageListViewController = [[appDelegate appController] messageListViewController];
    NSAssert(messageListViewController != nil, @"messageListViewController is nil");
    
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    NSAssert(messageListController != nil, @"messageListController is nil");
    
    SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");
    
    if([draftsLocalFolder moveMessage:_saveDraftUID toRemoteFolder:trashFolder.fullName]) {
        [[[appDelegate appController] messageListViewController] reloadMessageList:YES];

        SMMessageThread *currentMessageThread = [[[appDelegate appController] messageThreadViewController] currentMessageThread];
        
        if(currentMessageThread != nil) {
            if(currentMessageThread.messagesCount == 1) {
                SMMessage *firstMessage = currentMessageThread.messagesSortedByDate[0];
                
                if(firstMessage.uid == _saveDraftUID) {
                    [[[appDelegate appController] messageThreadViewController] setMessageThread:nil];
                }
            }
            else {
                for(SMMessage *m in currentMessageThread.messagesSortedByDate) {
                    if(m.uid == _saveDraftUID) {
                        [[[appDelegate appController] messageThreadViewController] updateMessageThread];
                        break;
                    }
                }
            }
        }
    }
    
    _saveDraftUID = 0;
}

@end
