//
//  SMMailboxToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/23/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMailboxToolbarViewController.h"

@interface SMMailboxToolbarViewController ()

@end

@implementation SMMailboxToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)addLabelButtonAction:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController showNewLabelSheet:nil];
}

@end
