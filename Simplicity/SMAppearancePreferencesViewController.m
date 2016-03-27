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
#import "SMMailboxViewController.h"
#import "SMAppearancePreferencesViewController.h"

@interface SMAppearancePreferencesViewController ()
@property (weak) IBOutlet NSButton *fixedSizeFontButton;
@property (weak) IBOutlet NSButton *regularFontButton;
@property (weak) IBOutlet NSPopUpButton *mailboxThemeList;
@end

@implementation SMAppearancePreferencesViewController {
    NSArray *_mailboxThemeNames;
    NSArray *_mailboxThemeValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _mailboxThemeNames = @[@"Light", @"Medium light", @"Medium dark", @"Dark"];
    _mailboxThemeValues = @[@(SMMailboxTheme_Light), @(SMMailboxTheme_MediumLight), @(SMMailboxTheme_MediumDark), @(SMMailboxTheme_Dark)];

    [_mailboxThemeList removeAllItems];
    [_mailboxThemeList addItemsWithTitles:_mailboxThemeNames];

    //
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger mailboxThemeValue = [[appDelegate preferencesController] mailboxTheme];
    
    NSAssert(mailboxThemeValue < _mailboxThemeNames.count, @"bad mailboxThemeValue %lu loaded from preferences", mailboxThemeValue);

    [_mailboxThemeList selectItemAtIndex:mailboxThemeValue];
}

- (IBAction)regularFontButtonAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)fixedSizeButtonAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)mailboxThemeListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SMMailboxTheme mailboxThemeValue = (SMMailboxTheme)[_mailboxThemeList indexOfSelectedItem];

    [[appDelegate preferencesController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] accountsViewController] setMailboxTheme:mailboxThemeValue];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

@end
