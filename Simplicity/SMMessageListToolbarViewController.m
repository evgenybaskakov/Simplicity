//
//  SMMessageListToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMessageListViewController.h"
#import "SMMessageListToolbarViewController.h"

@interface SMMessageListToolbarViewController ()

@end

@implementation SMMessageListToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
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

@end
