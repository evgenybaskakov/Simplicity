//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebView.h>

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOpAppendMessage.h"
#import "SMOpDeleteMessages.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMTokenField.h"
#import "SMOutboxController.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMMessageEditorWindowController.h"
#import "SMMailLogin.h"

@implementation SMMessageEditorWindowController {
    NSString *_draftsFolderName;
    MCOMessageBuilder *_saveDraftMessage;
    SMOpAppendMessage *_saveDraftOp;
    uint32_t _saveDraftUID;
}

- (void)awakeFromNib {
	NSLog(@"%s", __func__);

	// To
	
	_toBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];

	[_toBoxView addSubview:_toBoxViewController.view];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

	// Cc

	_ccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
	
	[_ccBoxView addSubview:_ccBoxViewController.view];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
	
	// Bcc
	
	_bccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
	
	[_bccBoxView addSubview:_bccBoxViewController.view];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
	
	// register events
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageSavedToDrafts:) name:@"MessageAppended" object:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	[_toBoxViewController.label setStringValue:@"To:"];
	[_ccBoxViewController.label setStringValue:@"Cc:"];
	[_bccBoxViewController.label setStringValue:@"Bcc:"];
	
	[_messageTextEditor setFrameLoadDelegate:self];
	[_messageTextEditor setPolicyDelegate:self];
	[_messageTextEditor setResourceLoadDelegate:self];
	[_messageTextEditor setCanDrawConcurrently:YES];
	[_messageTextEditor setEditable:YES];
	
	[_sendButton setEnabled:NO];
}

#pragma mark Actions

- (IBAction)sendAction:(id)sender {
	MCOMessageBuilder *message = [self createMessageData];
    NSAssert(message != nil, @"no message body");

	NSLog(@"%s: '%@'", __func__, message);

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];
	
	[[appController outboxController] sendMessage:message];

	[self close];
}

- (IBAction)saveAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    if(_draftsFolderName == nil) {
        SMFolder *draftsFolder = [[[appDelegate model] mailbox] getFolderByKind:SMFolderKindDrafts];
        NSAssert(draftsFolder, @"no drafts folder");

        _draftsFolderName = draftsFolder.fullName;
        NSAssert(_draftsFolderName, @"no drafts folder name");
    }

    [_saveDraftOp cancel];
    
    MCOMessageBuilder *message = [self createMessageData];
    NSAssert(message != nil, @"no message body");
    
    NSLog(@"%s: '%@'", __func__, message);
    
    SMOpAppendMessage *op = [[SMOpAppendMessage alloc] initWithMessage:message remoteFolderName:_draftsFolderName];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];

    _saveDraftMessage = message;
    _saveDraftOp = op;
}

- (IBAction)attachAction:(id)sender {
	NSLog(@"%s", __func__);
}

#pragma mark Message creation

- (MCOMessageBuilder*)createMessageData {
	MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];

	//TODO: custom from
	[[builder header] setFrom:[MCOAddress addressWithDisplayName:@"Evgeny Baskakov" mailbox:SMTP_USERNAME]];

	// TODO: form an array of addresses and names based on _toField contents
	NSArray *toAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:_toBoxViewController.tokenField.stringValue]];
	[[builder header] setTo:toAddresses];

	// TODO: form an array of addresses and names based on _ccField contents
	NSArray *ccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:_ccBoxViewController.tokenField.stringValue]];
	[[builder header] setCc:ccAddresses];
	
	// TODO: form an array of addresses and names based on _bccField contents
	NSArray *bccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:@"TODO" mailbox:_bccBoxViewController.tokenField.stringValue]];
	[[builder header] setBcc:bccAddresses];

	// TODO: check subject length, issue a warning if empty
	[[builder header] setSubject:_subjectField.stringValue];

	NSString *messageText = [(DOMHTMLElement *)[[[_messageTextEditor mainFrame] DOMDocument] documentElement] outerHTML];
	//TODO (send plain text): [(DOMHTMLElement *)[[[webView mainFrame] DOMDocument] documentElement] outerText];

	[builder setHTMLBody:messageText];

	//TODO (local attachments): [builder addAttachment:[MCOAttachment attachmentWithContentsOfFile:@"/Users/foo/Pictures/image.jpg"]];

	return builder;
}

#pragma mark UI elements collaboration

- (void)processAddressFieldEditingEnd:(NSNotification*)notification {
	id object = [notification object];
	
	if(object == _toBoxViewController) {
		NSString *toValue = [[_toBoxViewController.tokenField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
		
		// TODO: verify the destination email address / recepient name more carefully

		[_sendButton setEnabled:(toValue.length != 0)];
	}
}

#pragma mark Message after-saving actions

- (void)messageSavedToDrafts:(NSNotification *)notification {
    MCOMessageBuilder *message = [[notification userInfo] objectForKey:@"Message"];
    uint32_t uid = [[[notification userInfo] objectForKey:@"UID"] unsignedIntValue];
 
    if(message == _saveDraftMessage) {
        if(_saveDraftUID != 0) {
            // there is a previously saved draft, delete it
            NSAssert(_draftsFolderName, @"no drafts folder name");
            SMOpDeleteMessages *op = [[SMOpDeleteMessages alloc] initWithUids:[MCOIndexSet indexSetWithIndex:_saveDraftUID] remoteFolderName:_draftsFolderName];

            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate appController] operationExecutor] enqueueOperation:op];
        }

        _saveDraftMessage = nil;
        _saveDraftOp = nil;
        _saveDraftUID = uid;
    }
}

@end
