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
#import "SMGeneralPreferencesViewController.h"
#import "SMPreferencesWindowController.h"

@implementation SMPreferencesWindowController {
    NSArray *_tabNames;
    NSArray *_tabViewControllers;
    SMAccountPreferencesViewController *_accountPreferencesViewController;
    SMGeneralPreferencesViewController *_generalPreferencesViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    _accountPreferencesViewController = [[SMAccountPreferencesViewController alloc] initWithNibName:@"SMAccountPreferencesViewController" bundle:nil];
    _generalPreferencesViewController = [[SMGeneralPreferencesViewController alloc] initWithNibName:@"SMGeneralPreferencesViewController" bundle:nil];

    _tabNames = @[@"Accounts", @"General"];
    _tabViewControllers = @[_accountPreferencesViewController, _generalPreferencesViewController];
    
    [self toolbarToggleAccountAction:self];
}

- (void)selectTab:(NSUInteger)idx {
    for(NSView *subview in _preferencesView.subviews) {
        [subview removeFromSuperview];
    }
    
    [_preferencesToolbar setSelectedItemIdentifier:_tabNames[idx]];
    
    NSViewController *tabViewController = _tabViewControllers[idx];
    
    [self setInnerSize:NSMakeSize(tabViewController.view.frame.size.width, tabViewController.view.frame.size.height)];
    
    [_preferencesView addSubview:tabViewController.view];
    _preferencesView.frame = tabViewController.view.frame;
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
    [[appDelegate appController] hidePreferencesWindow];
}

- (IBAction)toolbarToggleAccountAction:(id)sender {
    [self selectTab:0];
}

- (IBAction)toolbarToggleGeneralAction:(id)sender {
    [self selectTab:0];
}

- (IBAction)closePreferencesAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hidePreferencesWindow];
}

- (void)reloadAccounts {
    [_accountPreferencesViewController reloadAccounts];
}

- (void)showAccount:(NSString*)accountName {
    [_accountPreferencesViewController showAccount:accountName];
}

@end
