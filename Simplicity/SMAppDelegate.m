//
//  SMAppDelegate.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMAccountsViewController.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMAddressBookController.h"
#import "SMUnifiedAccount.h"
#import "SMAttachmentStorage.h"
#import "SMMessageComparators.h"
#import "SMImageRegistry.h"
#import "SMAppController.h"
#import "SMAppDelegate.h"

@implementation SMAppDelegate {
    NSMutableArray<SMUserAccount*> *_accounts;
}

- (id)init {
    self = [ super init ];

    if(self) {
        _preferencesController = [[SMPreferencesController alloc] init];
        _attachmentStorage = [[SMAttachmentStorage alloc] init];
        _messageComparators = [[SMMessageComparators alloc] init];
        _addressBookController = [[SMAddressBookController alloc] init];
        _unifiedAccount = [[SMUnifiedAccount alloc] init];
        _imageRegistry = [[SMImageRegistry alloc] init];
        _accounts = [NSMutableArray array];
    }
    
    SM_LOG_DEBUG(@"app delegate initialized");
    
    return self;
}

- (id<SMMailbox>)currentMailbox {
    if(_accounts.count == 0) {
        return nil;
    }
    
    return [[self currentAccount] mailbox];
}

- (id<SMMailboxController>)currentMailboxController {
    if(_accounts.count == 0) {
        return nil;
    }
    
    return [[self currentAccount] mailboxController];
}

- (id<SMAbstractAccount>)currentAccount {
    if(_accounts.count == 0) {
        return nil;
    }
    
    if(_currentAccountIsUnified) {
        return _unifiedAccount;
    }
    
    return _accounts[_currentAccountIdx];
}

- (BOOL)accountsExist {
    return _accounts.count != 0;
}

- (NSArray<SMUserAccount*>*)accounts {
    return _accounts;
}

- (void)setCurrentAccountIdx:(NSInteger)currentAccountIdx {
    NSAssert(currentAccountIdx == -1 || currentAccountIdx < _accounts.count, @"bad currentAccountIdx %lu", currentAccountIdx);
    
    _currentAccountIdx = currentAccountIdx;
}

- (void)addAccount {
    SMUserAccount *account = [[SMUserAccount alloc] initWithPreferencesController:_preferencesController];
    
    [_accounts addObject:account];
    
    [account initSession:_accounts.count-1];
    [account getIMAPServerCapabilities];
    [account initOpExecutor];
}

- (void)removeAccount:(NSUInteger)accountIdx {
    NSAssert(accountIdx < _accounts.count, @"bad accountIdx %lu", accountIdx);

    if(_currentAccountIdx >= accountIdx && _currentAccountIdx > 0) {
        _currentAccountIdx--;
    }
    
    [_accounts[accountIdx] stopAccount];
    [_accounts removeObjectAtIndex:accountIdx];
    
    [[[[NSApplication sharedApplication] delegate] preferencesController] removeAccount:accountIdx];
}

- (void)setCurrentAccount:(id<SMAbstractAccount>)account {
    NSAssert(account, @"no account provided");
    
    if(account == _unifiedAccount) {
        _currentAccountIsUnified = YES;
    }
    else {
        _currentAccountIdx = NSNotFound;
        
        for(NSUInteger i = 0; i < _accounts.count; i++) {
            if(_accounts[i] == account) {
                _currentAccountIsUnified = NO;
                _currentAccountIdx = i;
                break;
            }
        }
        
        NSAssert(_currentAccountIdx != NSNotFound, @"provided mailbox not found");
    }
    
    _preferencesController.currentAccount = (_currentAccountIsUnified? UNIFIED_ACCOUNT_IDX : _currentAccountIdx);
}

- (void)enableOrDisableAccountControls {
    BOOL enableElements = (_accounts.count != 0);

    _appController.composeMessageMenuItem.enabled = NO;
    _appController.composeMessageButton.enabled = enableElements;
    _appController.trashButton.enabled = enableElements;
//TODO        _appController.searchField.enabled = enableElements;
    _appController.composeMessageMenuItem.enabled = enableElements;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    _window.titleVisibility = NSWindowTitleHidden;
    
    [[_window windowController] setShouldCascadeWindows:NO];
    [_window setFrameAutosaveName:@"MainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUInteger accountsCount = [_preferencesController accountsCount];

    _appController.composeMessageMenuItem.enabled = accountsCount != 0? YES : NO;
    
    if(accountsCount == 0) {
        [self enableOrDisableAccountControls];

        [_appController showNewAccountWindow];
    }
    else {
        for(NSUInteger i = 0; i < accountsCount; i++) {
            [self addAccount];
        }

        _currentAccountIdx = _preferencesController.currentAccount;
        if(_currentAccountIdx == UNIFIED_ACCOUNT_IDX) {
            _currentAccountIsUnified = YES;
        }
        
        [self enableOrDisableAccountControls];
    }

    [_appController.accountsViewController reloadAccountViews:YES];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];
    
    // TODO: detect an active editor

    appController.textFormatMenuItem.enabled = NO;
    appController.htmlTextFormatMenuItem.enabled = NO;
    appController.plainTextFormatMenuItem.enabled = NO;
}

- (void)windowDidResignMain:(NSNotification *)notification {
    [_appController closeSearchSuggestionsMenu];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [_appController closeSearchSuggestionsMenu];
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    [_appController closeSearchSuggestionsMenu];
}

- (void)windowWillBeginSheet:(NSNotification *)notification {
    [_appController closeSearchSuggestionsMenu];
}

- (void)windowWillMove:(NSNotification *)notification {
    [_appController closeSearchSuggestionsMenu];
}

+ (NSURL*)appDataDir {
    NSURL* appSupportDir = nil;
    NSArray* appSupportDirs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    if([appSupportDirs count] > 0) {
        appSupportDir = (NSURL*)[appSupportDirs objectAtIndex:0];
    } else {
        SM_LOG_DEBUG(@"cannot get path to app dir");
        
        appSupportDir = [NSURL fileURLWithPath:@"~/Library/Application Support/" isDirectory:YES];
    }
    
    return [appSupportDir URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
}

@end
