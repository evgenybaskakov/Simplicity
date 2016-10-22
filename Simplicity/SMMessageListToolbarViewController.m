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
#import "SMMessageEditorViewController.h"
#import "SMMessageListToolbarViewController.h"

@interface SMMessageListToolbarViewController ()

@end

@implementation SMMessageListToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setReplyButtonImage) name:@"DefaultReplyActionChanged" object:nil];

    [self setReplyButtonImage];
    
    _replyButton.longClickAction = @selector(replyButtonLongClickAction:);
    
    for(NSButton *control in @[_composeMessageButton, _replyButton, _starButton, _trashButton]) {
        [self scaleImage:control];
    }
}

- (void)scaleImage:(NSButton*)button {
    NSImage *img = [button image];
    NSSize buttonSize = [[button cell] cellSize];
    [img setSize:NSMakeSize(buttonSize.height/1.8, buttonSize.height/1.8)];
    [button setImage:img];
}

- (void)setReplyButtonImage {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    _replyButton.image = [[appDelegate preferencesController] defaultReplyAction] == SMDefaultReplyAction_ReplyAll? appDelegate.imageRegistry.replyAllSmallImage : appDelegate.imageRegistry.replySmallImage;

    [self scaleImage:_replyButton];
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
        [self composeReply:SMEditorReplyKind_ReplyAll];
    }
    else {
        [self composeReply:SMEditorReplyKind_ReplyOne];
    }
}

- (void)replyOneButtonAction:(id)sender {
    [self composeReply:SMEditorReplyKind_ReplyOne];
}

- (void)replyAllButtonAction:(id)sender {
    [self composeReply:SMEditorReplyKind_ReplyAll];
}

- (void)forwardButtonAction:(id)sender {
    [self composeReply:SMEditorReplyKind_Forward];
}

- (void)replyButtonLongClickAction:(id)sender {
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    
    [[theMenu addItemWithTitle:@"Reply" action:@selector(replyOneButtonAction:) keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:@"Reply All" action:@selector(replyAllButtonAction:) keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:@"Forward" action:@selector(forwardButtonAction:) keyEquivalent:@""] setTarget:self];
    
    [theMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(_replyButton.bounds.size.width-8, _replyButton.bounds.size.height-1) inView:_replyButton];
    
    NSWindow* window = [_replyButton window];
    
    NSEvent* fakeMouseUp = [NSEvent mouseEventWithType:NSLeftMouseUp
                                              location:_replyButton.bounds.origin
                                         modifierFlags:0
                                             timestamp:[NSDate timeIntervalSinceReferenceDate]
                                          windowNumber:[window windowNumber]
                                               context:[NSGraphicsContext currentContext]
                                           eventNumber:0
                                            clickCount:1
                                              pressure:0.0];
    
    [window postEvent:fakeMouseUp atStart:YES];
}

- (void)composeReply:(SMEditorReplyKind)replyKind {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageThread *messageThread = [[[appDelegate appController] messageThreadViewController] currentMessageThread];
    NSAssert(messageThread, @"no message thread selected");

    SMMessage *m = messageThread.messagesSortedByDate[0];
    NSAssert(m, @"no message");

    NSString *replySubject = m.subject;
    if(replyKind == SMEditorReplyKind_Forward) {
        replySubject = [NSString stringWithFormat:@"Fw: %@", replySubject];
    }
    else {
        if(![SMStringUtils string:replySubject hasPrefix:@"Re: " caseInsensitive:YES]) {
            replySubject = [NSString stringWithFormat:@"Re: %@", replySubject];
        }
    }

    NSMutableArray<SMAddress*> *toAddressList = nil;
    NSMutableArray<SMAddress*> *ccAddressList = nil;
    
    [SMMessageEditorViewController getReplyAddressLists:m replyKind:replyKind accountAddress:messageThread.account.accountAddress to:&toAddressList cc:&ccAddressList];
    
    SMEditorContentsKind editorKind = (replyKind == SMEditorReplyKind_Forward ? kUnfoldedForwardEditorContentsKind : kUnfoldedReplyEditorContentsKind);
    
    // TODO: also detect if the current message is in raw text; compose reply likewise
    Boolean plainText = [appDelegate.preferencesController preferableMessageFormat] == SMPreferableMessageFormat_RawText? YES : NO;
    [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering plainText:plainText subject:replySubject to:toAddressList cc:ccAddressList bcc:nil draftUid:m.uid mcoAttachments:m.attachments editorKind:editorKind];
}

@end
