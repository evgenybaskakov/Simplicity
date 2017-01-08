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
#import "SMStringUtils.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMOperationExecutor.h"
#import "SMOpAppendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMUserAccount.h"
#import "SMMessageBuilder.h"
#import "SMAccountMailbox.h"
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
#import "SMOpSendMessage.h"

@implementation SMMessageEditorController {
    NSMutableArray<SMAttachmentItem*> *_attachmentItems;
    NSMutableArray<SMAttachmentItem*> *_inlinedImageAttachmentItems;
    MCOMessageBuilder *_saveDraftMessage;
    SMOpAppendMessage *_saveDraftOp;
    MCOMessageBuilder *_prevSaveDraftMessage;
    SMOpAppendMessage *_prevSaveDraftOp;
    uint32_t _saveDraftUID;
    BOOL _shouldDeleteSavedDraft;
}

- (id)initWithDraftUID:(uint32_t)draftMessageUid {
    self = [super init];
    
    if(self) {
        _attachmentItems = [NSMutableArray array];
        _inlinedImageAttachmentItems = [NSMutableArray array];
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

- (NSURL*)draftTempDir {
    NSURL *appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    return [appDataDir URLByAppendingPathComponent:[NSString stringWithFormat:@"DraftTemp"] isDirectory:YES];
}

- (NSString*)addInlinedImage:(NSURL*)url {
    SMAttachmentItem *attachmentItem = [[SMAttachmentItem alloc] initWithLocalFilePath:url.path];
    
    NSData *fileData = [NSData dataWithContentsOfFile:url.path];
    if(fileData == nil) {
        SM_LOG_ERROR(@"failed to read file '%@'", url);
        
        // TODO: show alert
        return @"";
    }
    
    NSString *checksum = [SMStringUtils sha1WithData:fileData];
    SM_LOG_INFO(@"file '%@' checksum %@", url, checksum);

    [attachmentItem.mcoAttachment setContentID:checksum];
    
    [_inlinedImageAttachmentItems addObject:attachmentItem];
    
    // TODO: create a uniquely named subdirectory

    NSURL *dirUrl = [self draftTempDir];
    
    NSString *dirPath = [dirUrl path];
    NSAssert(dirPath != nil, @"dirPath is nil");
    
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        SM_LOG_ERROR(@"failed to create directory '%@', error: %@", dirPath, error);
        
        // TODO: show alert
        return @"";
    }
    
    NSURL *cacheFileUrl = [dirUrl URLByAppendingPathComponent:checksum];
    
    [[NSFileManager defaultManager] removeItemAtURL:cacheFileUrl error:nil];
    
    if(![[NSFileManager defaultManager] copyItemAtURL:url toURL:cacheFileUrl error:&error]) {
        SM_LOG_ERROR(@"failed to copy '%@' to %@: %@", url, cacheFileUrl, error);
        
        // TODO: show alert
        return @"";
    }
    
    return attachmentItem.mcoAttachment.contentID;
}

#pragma mark Actions

- (BOOL)sendMessage:(NSString*)messageText plainText:(BOOL)plainText subject:(NSString*)subject from:(SMAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc account:(SMUserAccount*)account {
    
    // TODO: why attachments are in this object, not parameters?
    
    SMMessageBuilder *messageBuilder = [[SMMessageBuilder alloc] initWithMessageText:messageText plainText:plainText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:_attachmentItems inlineAttachmentItems:_inlinedImageAttachmentItems account:account];
    
    SM_LOG_DEBUG(@"'%@'", messageBuilder.mcoMessageBuilder);
    
    SMOutgoingMessage *outgoingMessage = [[SMOutgoingMessage alloc] initWithMessageBuilder:messageBuilder];
    
    return [[account outboxController] sendMessage:outgoingMessage postSendAction:^(SMOpSendMessage *op) {
        SMOutgoingMessage *message = op.outgoingMessage;
        SMUserAccount *account = message.messageBuilder.account;
        
        [[account outboxController] finishMessageSending:message];
        
        [self deleteSavedDraft:account];

        if(self->_saveDraftOp) {
            if(![self->_saveDraftOp cancelOp]) {
                // Could not cancel save op. To avoid orphaned drafts,
                // schedule its deletion for later.
                self->_shouldDeleteSavedDraft = YES;
            }
        }}];
}

- (void)saveDraft:(NSString*)messageText plainText:(BOOL)plainText subject:(NSString*)subject from:(SMAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc account:(SMUserAccount*)account {
    NSAssert(!_shouldDeleteSavedDraft, @"_shouldDeleteSavedDraft is set (which means that message was already sent and no more savings allowed)");
    
    SMFolder *draftsFolder = [[account mailbox] draftsFolder];
    if(!draftsFolder) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Dismiss"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot save draft, because the Drafts folder is not availble for account '%@'.", account.accountName]];
        [alert setInformativeText:@"Check account settings or choose another account to save the draft in the 'From' field."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return;
    }
    
    NSAssert(draftsFolder.fullName, @"drafts folder has no name in account %@", account.accountName);
    
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

    SMMessageBuilder *messageBuilder = [[SMMessageBuilder alloc] initWithMessageText:messageText plainText:plainText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:_attachmentItems inlineAttachmentItems:_inlinedImageAttachmentItems account:account];
    
    SM_LOG_DEBUG(@"'%@'", messageBuilder.mcoMessageBuilder);
    
    SMOpAppendMessage *op = [[SMOpAppendMessage alloc] initWithMessageBuilder:messageBuilder remoteFolderName:draftsFolder.fullName flags:(MCOMessageFlagSeen | MCOMessageFlagDraft) operationExecutor:[account operationExecutor]];
    
    op.postAction = ^(SMOperation *op) {
        SMOpAppendMessage *appendOp = (SMOpAppendMessage*)op;
        
        [self messageSavedToDrafts:appendOp.account message:appendOp.messageBuilder uid:appendOp.uid];
    };
    
    [[account operationExecutor] enqueueOperation:op];
    
    _saveDraftMessage = messageBuilder.mcoMessageBuilder;
    _saveDraftOp = op;
    
    _hasUnsavedAttachments = NO;
}

#pragma mark Message after-saving actions

- (void)messageSavedToDrafts:(SMUserAccount*)account message:(SMMessageBuilder*)messageBuilder uid:(uint32_t)uid {
    // TODO: use SMMessage, not builder (?)
    
    NSAssert(account != nil, @"no account in the notification");
    
    SM_LOG_DEBUG(@"uid %u", uid);
    
    MCOMessageBuilder *mcoMessageBuilder = messageBuilder.mcoMessageBuilder;
    
    if(mcoMessageBuilder == _prevSaveDraftMessage || mcoMessageBuilder == _saveDraftMessage) {
        [self deleteSavedDraft:account];
        
        if(mcoMessageBuilder == _prevSaveDraftMessage) {
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
            [self deleteSavedDraft:account];
        }
    }
}

- (BOOL)hasSavedDraft {
    return (_saveDraftUID != 0);
}

- (void)deleteSavedDraft:(SMUserAccount*)account {
    if(_saveDraftUID == 0) {
        SM_LOG_DEBUG(@"No saved message draft");
        return;
    }
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(appDelegate != nil, @"no appDelegate");
    
    id<SMMailbox> mailbox = [account mailbox];
    NSAssert(mailbox != nil, @"no mailbox");
    
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    SMLocalFolder *draftsLocalFolder = (SMLocalFolder*)[[account localFolderRegistry] getLocalFolderByKind:SMFolderKindDrafts];
    NSAssert(draftsLocalFolder != nil, @"no local drafts folder");
    
    SMMessageListViewController *messageListViewController = [[appDelegate appController] messageListViewController];
    NSAssert(messageListViewController != nil, @"messageListViewController is nil");
    
    SMMessageListController *messageListController = [account messageListController];
    NSAssert(messageListController != nil, @"messageListController is nil");

    if([draftsLocalFolder moveMessage:0 uid:_saveDraftUID toRemoteFolder:trashFolder.fullName]) {
        [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
    }
    
    _saveDraftUID = 0;
}

@end
