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
#import "SMAppearancePreferencesViewController.h"
#import "SMLabelPreferencesViewController.h"
#import "SMSignaturePreferencesViewController.h"
#import "SMAdvancedPreferencesViewController.h"
#import "SMPreferencesWindowController.h"

@implementation SMPreferencesWindowController {
    NSArray<NSString*> *_tabNames;
    NSArray<NSViewController*> *_tabViewControllers;
    NSUInteger _currentTabIdx;
    SMAccountPreferencesViewController *_accountPreferencesViewController;
    SMGeneralPreferencesViewController *_generalPreferencesViewController;
    SMAppearancePreferencesViewController *_appearancePreferencesViewController;
    SMSignaturePreferencesViewController *_signaturePreferencesViewController;
    SMLabelPreferencesViewController *_labelPreferencesViewController;
    SMAdvancedPreferencesViewController *_advancedPreferencesViewController;
    __weak IBOutlet NSButton *_closeButton;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    _accountPreferencesViewController = [[SMAccountPreferencesViewController alloc] initWithNibName:@"SMAccountPreferencesViewController" bundle:nil];
    _generalPreferencesViewController = [[SMGeneralPreferencesViewController alloc] initWithNibName:@"SMGeneralPreferencesViewController" bundle:nil];
    _appearancePreferencesViewController = [[SMAppearancePreferencesViewController alloc] initWithNibName:@"SMAppearancePreferencesViewController" bundle:nil];
    _signaturePreferencesViewController = [[SMSignaturePreferencesViewController alloc] initWithNibName:@"SMSignaturePreferencesViewController" bundle:nil];
    _labelPreferencesViewController = [[SMLabelPreferencesViewController alloc] initWithNibName:@"SMLabelPreferencesViewController" bundle:nil];
    _advancedPreferencesViewController = [[SMAdvancedPreferencesViewController alloc] initWithNibName:@"SMAdvancedPreferencesViewController" bundle:nil];

    _tabNames = @[@"Accounts", @"General", @"Appearance", @"Signature", @"Labels", @"Advanced"];
    _tabViewControllers = @[_accountPreferencesViewController, _generalPreferencesViewController, _appearancePreferencesViewController, _signaturePreferencesViewController, _labelPreferencesViewController, _advancedPreferencesViewController];
    
    [_preferencesToolbar setSelectedItemIdentifier:_tabNames[0]];
    
    [self selectTab:0];
}

- (void)selectTab:(NSUInteger)idx {
    NSView *view = [self window].contentView;
    
    for(NSView *subview in view.subviews) {
        if(subview != _closeButton) {
            [subview removeFromSuperview];
        }
    }

    _currentTabIdx = idx;
   
    [self adjustWindowSize:_tabViewControllers[idx].view.frame.size];

    [view addSubview:_tabViewControllers[idx].view];
}

- (void)adjustWindowSize:(NSSize)viewSize {
    NSViewController *tabViewController = _tabViewControllers[_currentTabIdx];
    
    NSView *view = [self window].contentView;

    CGFloat toolbarHeight = [self window].frame.size.height - [self window].contentView.frame.size.height;
    CGFloat windowHeight = viewSize.height + toolbarHeight;
    
    [self setInnerSize:NSMakeSize(viewSize.width, windowHeight)];

    [view setFrameSize:viewSize];
    
    [tabViewController.view setFrameSize:viewSize];
    [tabViewController.view setFrameOrigin:NSMakePoint(0, 0)];
}

- (void)setInnerSize:(NSSize)innerSize {
    CGFloat origY = NSMaxY([[self window] frame]);
    
    NSRect origWindowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
    NSRect newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect(NSMinX(origWindowFrame), NSMaxY(origWindowFrame), origWindowFrame.size.width, innerSize.height) styleMask:[[self window] styleMask]];
    
    newWindowFrame.size = innerSize;
    newWindowFrame.origin.y = origY - innerSize.height;
    
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

- (IBAction)toolbarToggleAppearanceAction:(id)sender {
    [self selectTab:2];
}

- (IBAction)toolbarToggleSignatureAction:(id)sender {
    [self selectTab:3];
}

- (IBAction)toolbarToggleLabelsAction:(id)sender {
    [self selectTab:4];
}

- (IBAction)toolbarToggleAdvancedAction:(id)sender {
    [self selectTab:5];
}

- (IBAction)closeAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hidePreferencesWindow];
}

- (void)reloadAccounts {
    [_accountPreferencesViewController reloadAccounts];
    [_signaturePreferencesViewController reloadAccountSignatures];
    [_labelPreferencesViewController reloadAccountLabels];
}

- (void)showAccount:(NSString*)accountName {
    [self selectTab:0];
    [_accountPreferencesViewController showAccount:accountName];
}

@end
