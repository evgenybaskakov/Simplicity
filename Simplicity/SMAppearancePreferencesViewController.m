//
//  SMAppearancePreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/20/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMAccountsViewController.h"
#import "SMPreferencesWindowController.h"
#import "SMMailboxViewController.h"
#import "SMAppearancePreferencesViewController.h"

@interface SMAppearancePreferencesViewController ()
@property (weak) IBOutlet NSButton *fixedFontButton;
@property (weak) IBOutlet NSButton *regularFontButton;
@property (weak) IBOutlet NSPopUpButton *mailboxThemeList;
@property (weak) IBOutlet NSLayoutConstraint *heightConstraint1;
@property (weak) IBOutlet NSLayoutConstraint *heightConstraint2;
@property (weak) IBOutlet NSLayoutConstraint *heightConstraint3;
@property (weak) IBOutlet NSLayoutConstraint *heightConstraint4;
@end

@implementation SMAppearancePreferencesViewController {
    NSFont *_regularFont;
    NSFont *_fixedFont;
    NSArray *_mailboxThemeNames;
    NSArray *_mailboxThemeValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setPostsFrameChangedNotifications:YES];
    
    _mailboxThemeNames = @[@"Light", @"Medium light", @"Medium dark", @"Dark"];
    _mailboxThemeValues = @[@(SMMailboxTheme_Light), @(SMMailboxTheme_MediumLight), @(SMMailboxTheme_MediumDark), @(SMMailboxTheme_Dark)];

    [_mailboxThemeList removeAllItems];
    [_mailboxThemeList addItemsWithTitles:_mailboxThemeNames];

    //
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger mailboxThemeValue = [[appDelegate preferencesController] mailboxTheme];
    
    NSAssert(mailboxThemeValue < _mailboxThemeNames.count, @"bad mailboxThemeValue %lu loaded from preferences", mailboxThemeValue);

    [_mailboxThemeList selectItemAtIndex:mailboxThemeValue];
    
    //
    
    _regularFont = [[appDelegate preferencesController] regularMessageFont];
    [self reloadRegularFontButton];
    
    _fixedFont = [[appDelegate preferencesController] fixedMessageFont];
    [self reloadFixedFontButton];
}

static const NSUInteger maxButtonFontSize = 24;

- (void)reloadRegularFontButton {
    _regularFontButton.title = [NSString stringWithFormat:@"%@ %lu", _regularFont.displayName, (NSUInteger)_regularFont.pointSize];
    _regularFontButton.font = _regularFont.pointSize > maxButtonFontSize? [NSFont fontWithDescriptor:_regularFont.fontDescriptor size:maxButtonFontSize] : _regularFont;
    
    [self adjustWindowSize];
}

- (void)reloadFixedFontButton {
    _fixedFontButton.title = [NSString stringWithFormat:@"%@ %lu", _fixedFont.displayName, (NSUInteger)_fixedFont.pointSize];
    _fixedFontButton.font = _fixedFont.pointSize > maxButtonFontSize? [NSFont fontWithDescriptor:_fixedFont.fontDescriptor size:maxButtonFontSize] : _fixedFont;
    
    [self adjustWindowSize];
}

- (void)adjustWindowSize {
    [self.view layoutSubtreeIfNeeded];
    
    CGFloat newHeight = _heightConstraint1.constant + _heightConstraint2.constant + _heightConstraint3.constant + _heightConstraint4.constant + _regularFontButton.intrinsicContentSize.height + _fixedFontButton.intrinsicContentSize.height + _mailboxThemeList.intrinsicContentSize.height;
    
    [(SMPreferencesWindowController*)self.view.window.windowController adjustWindowSize:NSMakeSize(NSWidth(self.view.frame), newHeight)];
}

- (void)notifyFontsChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SMDefaultMessageFontChanged" object:nil userInfo:nil];
}

- (void)setRegularFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _regularFont = [fontManager convertFont:[fontManager selectedFont]];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setRegularMessageFont:_regularFont];
    
    [self notifyFontsChanged];
    [self reloadRegularFontButton];
}

- (void)setFixedFont:(id)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _fixedFont = [fontManager convertFont:[fontManager selectedFont]];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setFixedMessageFont:_fixedFont];
    
    [self notifyFontsChanged];
    [self reloadFixedFontButton];
}

- (IBAction)regularFontButtonAction:(id)sender {
    [self.view.window makeFirstResponder:self];

    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setSelectedFont:_regularFont isMultiple:NO];
    [fontManager setAction:@selector(setRegularFont:)];

    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    [fontPanel makeKeyAndOrderFront:sender];
}

- (IBAction)fixedSizeButtonAction:(id)sender {
    [self.view.window makeFirstResponder:self];
    
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    [fontManager setSelectedFont:_fixedFont isMultiple:NO];
    [fontManager setAction:@selector(setFixedFont:)];
    
    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    [fontPanel setWorksWhenModal:YES];
    [fontPanel makeKeyAndOrderFront:sender];
}

- (IBAction)mailboxThemeListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SMMailboxTheme mailboxThemeValue = (SMMailboxTheme)[_mailboxThemeList indexOfSelectedItem];

    [[appDelegate preferencesController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] accountsViewController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

@end
