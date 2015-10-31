//
//  SMPreferencesWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/30/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMAccountPreferencesViewController.h"
#import "SMPreferencesWindowController.h"

@implementation SMPreferencesWindowController {
    SMAccountPreferencesViewController *_accountPreferencesViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [_preferencesToolbar setSelectedItemIdentifier:@"Accounts"];

    _accountPreferencesViewController = [[SMAccountPreferencesViewController alloc] initWithNibName:@"SMAccountPreferencesViewController" bundle:nil];
    
    [_preferencesView addSubview:_accountPreferencesViewController.view];
    
    _preferencesView.frame = _accountPreferencesViewController.view.frame;
}

- (void)windowWillClose:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hidePreferences];
}

- (IBAction)toolbarToggleAccountAction:(id)sender {
    SM_LOG_INFO(@"toolbarToggleAccountAction");
}

- (IBAction)toolbarToggleGeneralAction:(id)sender {
    SM_LOG_INFO(@"toolbarToggleGeneralAction");
}

@end
