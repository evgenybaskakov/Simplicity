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
        [self composeReplyAll:sender];
    }
    else {
        [self composeReply:sender];
    }
}

- (void)composeReply:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (void)composeReplyAll:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

@end
