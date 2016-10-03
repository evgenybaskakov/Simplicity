//
//  SMMessageListToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMImageRegistry.h"
#import "SMStringUtils.h"
#import "SMAddress.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageListViewController.h"
#import "SMMessageListToolbarViewController.h"

@interface SMMessageListToolbarViewController ()

@end

@implementation SMMessageListToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setReplyButtonImage) name:@"DefaultReplyActionChanged" object:nil];

    [self setReplyButtonImage];
}

- (void)setReplyButtonImage {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    _replyButton.image = [[appDelegate preferencesController] defaultReplyAction] == SMDefaultReplyAction_ReplyAll? appDelegate.imageRegistry.replyAllSmallImage : appDelegate.imageRegistry.replySmallImage;
}

- (IBAction)composeMessageAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController composeMessageAction:self];
}

- (IBAction)moveToTrashAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController moveSelectedMessageThreadsToTrash];
}

- (IBAction)starButtonAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    [appController.messageListViewController toggleStarForSelected];
}

- (IBAction)replyButtonAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    if([[appDelegate preferencesController] defaultReplyAction] == SMDefaultReplyAction_ReplyAll) {
        [self composeReply:YES];
    }
    else {
        [self composeReply:NO];
    }
}

- (void)composeReply:(BOOL)replyAll {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageThread *messageThread = [[[appDelegate appController] messageThreadViewController] currentMessageThread];
    NSAssert(messageThread, @"no message thread selected");
    SMMessage *m = messageThread.messagesSortedByDate[0];
    NSAssert(m, @"no message");

    NSArray *toAddressList = (replyAll? m.toAddressList : @[m.fromAddress.mcoAddress]);
    NSArray *ccAddressList = (replyAll? m.ccAddressList : nil);

    // TODO: remove ourselves (myself) from CC and TO
    
    NSString *replySubject = m.subject;
    if(![SMStringUtils string:replySubject hasPrefix:@"Re: " caseInsensitive:YES]) {
        replySubject = [NSString stringWithFormat:@"Re: %@", replySubject];
    }

    // TODO: also detect if the current message is in raw text; compose reply likewise
    Boolean plainText = [appDelegate.preferencesController preferableMessageFormat] == SMPreferableMessageFormat_RawText? YES : NO;
    [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering plainText:plainText subject:replySubject to:toAddressList cc:ccAddressList bcc:nil draftUid:m.uid mcoAttachments:m.attachments editorKind:kUnfoldedReplyEditorContentsKind];
}

@end
