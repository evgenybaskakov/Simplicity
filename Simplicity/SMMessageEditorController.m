//
//  SMMessageEditorController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

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
#import "SMMessageEditorController.h"

@implementation SMMessageEditorController {
    NSMutableArray *_attachmentItems;
    NSString *_draftsFolderName;
    MCOMessageBuilder *_saveDraftMessage;
    SMOpAppendMessage *_saveDraftOp;
    MCOMessageBuilder *_prevSaveDraftMessage;
    SMOpAppendMessage *_prevSaveDraftOp;
    uint32_t _saveDraftUID;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _attachmentItems = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageSavedToDrafts:) name:@"MessageAppended" object:nil];
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
    
    NSLog(@"%s: '%@'", __func__, message);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [[appController outboxController] sendMessage:message];
}

- (void)saveDraft:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(_draftsFolderName == nil) {
        SMFolder *draftsFolder = [[[appDelegate model] mailbox] getFolderByKind:SMFolderKindDrafts];
        NSAssert(draftsFolder, @"no drafts folder");
        
        _draftsFolderName = draftsFolder.fullName;
        NSAssert(_draftsFolderName, @"no drafts folder name");
    }
    
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
    
    //NSLog(@"%s: '%@'", __func__, message);
    
    SMOpAppendMessage *op = [[SMOpAppendMessage alloc] initWithMessage:message remoteFolderName:_draftsFolderName];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
    
    _saveDraftMessage = message;
    _saveDraftOp = op;
}

#pragma mark Message creation

- (MCOMessageBuilder*)createMessageData:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc {
    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
    
    //TODO: custom from
    [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"Evgeny Baskakov" mailbox:SMTP_USERNAME]];
    
    // TODO: form an array of addresses and names based on _toField contents
    NSArray *toAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:to]];
    [[builder header] setTo:toAddresses];
    
    // TODO: form an array of addresses and names based on _ccField contents
    NSArray *ccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:cc]];
    [[builder header] setCc:ccAddresses];
    
    // TODO: form an array of addresses and names based on _bccField contents
    NSArray *bccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:bcc]];
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

- (void)messageSavedToDrafts:(NSNotification *)notification {
    MCOMessageBuilder *message = [[notification userInfo] objectForKey:@"Message"];
    uint32_t uid = [[[notification userInfo] objectForKey:@"UID"] unsignedIntValue];
    
    NSLog(@"%s: uids %u", __FUNCTION__, uid);
    
    if(message == _prevSaveDraftMessage || message == _saveDraftMessage) {
        if(_saveDraftUID != 0) {
            // there is a previously saved draft, delete it
            NSAssert(_draftsFolderName, @"no drafts folder name");
            SMOpDeleteMessages *op = [[SMOpDeleteMessages alloc] initWithUids:[MCOIndexSet indexSetWithIndex:_saveDraftUID] remoteFolderName:_draftsFolderName];
            
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate appController] operationExecutor] enqueueOperation:op];
            
            _saveDraftUID = 0;
        }
        
        if(message == _prevSaveDraftMessage) {
            _prevSaveDraftMessage = nil;
            _prevSaveDraftOp = nil;
        } else {
            _saveDraftMessage = nil;
            _saveDraftOp = nil;
        }
        
        _saveDraftUID = uid;
    }
}

@end
