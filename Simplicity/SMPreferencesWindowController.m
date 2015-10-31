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

    [self setInnerSize:NSMakeSize(_accountPreferencesViewController.view.frame.size.width, _accountPreferencesViewController.view.frame.size.height)];
    
    [_preferencesView addSubview:_accountPreferencesViewController.view];
    _preferencesView.frame = _accountPreferencesViewController.view.frame;
}

- (void)setInnerSize:(NSSize)innerSize {
    CGFloat toolbarHeight = [self window].frame.size.height - [self window].contentView.frame.size.height;
    innerSize.height += toolbarHeight;
    
    NSRect windowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
    NSRect newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - innerSize.height, innerSize.width, innerSize.height) styleMask:[[self window] styleMask]];

    [[self window] setFrame:newWindowFrame display:YES animate:[[self window] isVisible]];
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

- (IBAction)closePreferencesAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hidePreferences];
}

@end
