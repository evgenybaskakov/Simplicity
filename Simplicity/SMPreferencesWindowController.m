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
    NSView *view = [self window].contentView;
    
    for(NSView *subview in view.subviews) {
        [subview removeFromSuperview];
    }
    
    NSViewController *tabViewController = _tabViewControllers[idx];
    
    CGFloat toolbarHeight = [self window].frame.size.height - [self window].contentView.frame.size.height;
    CGFloat windowHeight = tabViewController.view.frame.size.height + toolbarHeight;

    [self setInnerSize:NSMakeSize(tabViewController.view.frame.size.width, windowHeight)];
    
    [view addSubview:tabViewController.view];
    [view setFrameSize:NSMakeSize(tabViewController.view.frame.size.width, tabViewController.view.frame.size.height)];
    
    [tabViewController.view setFrameOrigin:NSMakePoint(0, 0)];
}

- (void)setInnerSize:(NSSize)innerSize {
    NSRect origWindowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
    NSRect newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect(NSMinX(origWindowFrame), NSMaxY(origWindowFrame) - origWindowFrame.size.height, origWindowFrame.size.width, innerSize.height) styleMask:[[self window] styleMask]];

    newWindowFrame.size = innerSize;
    
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
    [self selectTab:1];
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
