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
#import "SMOperationExecutor.h"
#import "SMOpAppendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMOutboxController.h"
#import "SMMailLogin.h"
#import "SMAttachmentItem.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageEditorController.h"

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

#pragma mark Actions

- (void)sendMessage:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc {
    MCOMessageBuilder *message = [self createMessageData:messageText subject:subject to:to cc:cc bcc:bcc];
    NSAssert(message != nil, @"no message body");
    
    SM_LOG_DEBUG(@"'%@'", message);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [[appController outboxController] sendMessage:message postSendActionTarget:self postSendActionSelector:@selector(messageSentByServer:)];
}

- (void)messageSentByServer:(NSDictionary*)info {
    [self deleteSavedDraft];

    if(_saveDraftOp) {
        if(![_saveDraftOp cancelOp]) {
            // Could not cancel save op. To avoid orphaned drafts,
            // schedule its deletion for later.
            _shouldDeleteSavedDraft = YES;
        }
    }
}

- (void)saveDraft:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc {
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
    
    MCOMessageBuilder *message = [self createMessageData:messageText subject:subject to:to cc:cc bcc:bcc];
    NSAssert(message != nil, @"no message body");
    
    SM_LOG_DEBUG(@"'%@'", message);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *draftsFolder = [[[appDelegate model] mailbox] draftsFolder];
    NSAssert(draftsFolder && draftsFolder.fullName, @"no drafts folder");
    
    SMOpAppendMessage *op = [[SMOpAppendMessage alloc] initWithMessage:message remoteFolderName:draftsFolder.fullName flags:(MCOMessageFlagSeen | MCOMessageFlagDraft)];
    
    op.postActionTarget = self;
    op.postActionSelector = @selector(messageSavedToDrafts:);
    
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
    
    _saveDraftMessage = message;
    _saveDraftOp = op;
}

#pragma mark Message creation

- (MCOMessageBuilder*)createMessageData:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc {
    NSAssert(messageText, @"messageText is nil");
    NSAssert(subject, @"subject is nil");
    NSAssert(to, @"to is nil");
    NSAssert(cc, @"cc is nil");
    NSAssert(bcc, @"bcc is nil");

    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
    
    //TODO: custom from
    [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"Evgeny Baskakov" mailbox:SMTP_USERNAME]];
    
    // TODO: form an array of addresses and names based on _toField contents
    NSArray *toAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:to mailbox:to]];
    [[builder header] setTo:toAddresses];
    
    // TODO: form an array of addresses and names based on _ccField contents
    NSArray *ccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:cc mailbox:cc]];
    [[builder header] setCc:ccAddresses];
    
    // TODO: form an array of addresses and names based on _bccField contents
    NSArray *bccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:bcc mailbox:bcc]];
    [[builder header] setBcc:bccAddresses];
    
    // TODO: check subject length, issue a warning if empty
    [[builder header] setSubject:subject];
    
    //TODO (send plain text): [(DOMHTMLElement *)[[[webView mainFrame] DOMDocument] documentElement] outerText];
    
    [builder setHTMLBody:messageText];
    
    //TODO (local attachments): [builder addAttachment:[MCOAttachment attachmentWithContentsOfFile:@"/Users/foo/Pictures/image.jpg"]];
   
    for(SMAttachmentItem *attachmentItem in _attachmentItems) {
        NSString *attachmentFilePath = attachmentItem.filePath;
        NSAssert(attachmentFilePath != nil, @"attachmentFilePath is nil");

        MCOAttachment *mcoAttachment = [MCOAttachment attachmentWithContentsOfFile:attachmentFilePath];

        [builder addAttachment:mcoAttachment];
        // TODO: ???    - (void) addRelatedAttachment:(MCOAttachment *)attachment;
    }
    
    return builder;
}

#pragma mark Message after-saving actions

- (void)messageSavedToDrafts:(NSDictionary *)info {
    MCOMessageBuilder *message = [info objectForKey:@"Message"];
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

- (void)deleteSavedDraft {
    if(_saveDraftUID == 0) {
        SM_LOG_DEBUG(@"No saved message draft");
        return;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSAssert(appDelegate != nil, @"no appDelegate");
    
    SMMailbox *mailbox = [[appDelegate model] mailbox];
    NSAssert(mailbox != nil, @"no mailbox");
    
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    SMFolder *draftsFolder = [[[appDelegate model] mailbox] draftsFolder];
    NSAssert(draftsFolder && draftsFolder.fullName, @"no drafts folder");
    
    SMLocalFolder *draftsLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:draftsFolder.fullName];
    NSAssert(draftsLocalFolder != nil, @"no local drafts folder");
    
    SMMessageListViewController *messageListViewController = [[appDelegate appController] messageListViewController];
    NSAssert(messageListViewController != nil, @"messageListViewController is nil");
    
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    NSAssert(messageListController != nil, @"messageListController is nil");
    
    SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");
    
    if([draftsLocalFolder moveMessage:_saveDraftUID toRemoteFolder:trashFolder.fullName]) {
        [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
    }
    
    // TODO: if the current thread contains the draft
    //    [self updateMessageThread];
    
    _saveDraftUID = 0;
}

@end
