//
//  SMAppDelegate.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMFileUtils.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMAccountsViewController.h"
#import "SMMessageListToolbarViewController.h"
#import "SMMessageThreadAccountProxy.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMAddressBookController.h"
#import "SMRemoteImageLoadController.h"
#import "SMUnifiedAccount.h"
#import "SMNotificationsController.h"
#import "SMMessageComparators.h"
#import "SMImageRegistry.h"
#import "SMAttachmentStorage.h"
#import "SMAppController.h"
#import "SMAppDelegate.h"

@implementation SMAppDelegate {
    NSMutableArray<SMUserAccount*> *_accounts;
}

+ (void)restartApplication {
    NSString *path = [[NSBundle mainBundle] executablePath];
    NSString *processID = [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]];
    SM_LOG_INFO(@"New instance process identifier: %@", processID);
    
    [NSTask launchedTaskWithLaunchPath:path arguments:[NSArray arrayWithObjects:path, processID, nil]];
    [NSApp terminate: nil];
}

- (id)init {
    self = [ super init ];

    if(self) {
        _notificationController = [[SMNotificationsController alloc] init];
        _preferencesController = [[SMPreferencesController alloc] init];
        _messageComparators = [[SMMessageComparators alloc] init];
        _addressBookController = [[SMAddressBookController alloc] init];
        _remoteImageLoadController = [[SMRemoteImageLoadController alloc] init];
        _unifiedAccount = [[SMUnifiedAccount alloc] init];
        _imageRegistry = [[SMImageRegistry alloc] init];
        _messageThreadAccountProxy = [[SMMessageThreadAccountProxy alloc] init];
        _attachmentStorage = [[SMAttachmentStorage alloc] init];
        _accounts = [NSMutableArray array];
        
        [self ensureAppDirectoriesCreated];
    }
    
    SM_LOG_DEBUG(@"app delegate initialized");
    
    return self;
}

- (void)ensureAppDirectoriesCreated {
    NSString *dir = [[SMAppDelegate imageCacheDir] path];
    if(![SMFileUtils createDirectory:dir]) {
        SM_LOG_ERROR(@"cannot create directory %@", dir);
    }

    dir = [[SMAppDelegate draftTempDir] path];
    if(![SMFileUtils createDirectory:dir]) {
        SM_LOG_ERROR(@"cannot create directory %@", dir);
    }

    dir = [[SMAppDelegate systemTempDir] path];
    if(![SMFileUtils createDirectory:dir]) {
        SM_LOG_ERROR(@"cannot create directory %@", dir);
    }
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
    
    NSAssert(_currentAccountIdx >= 0 && _currentAccountIdx < _accounts.count, @"bad current account idx %ld", _currentAccountIdx);
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

    [self reconnectAccount:_accounts.count-1];
}

- (void)removeAccount:(NSUInteger)accountIdx {
    NSAssert(accountIdx < _accounts.count, @"bad accountIdx %lu", accountIdx);

    if(_currentAccountIdx >= accountIdx && _currentAccountIdx > 0) {
        _currentAccountIdx--;
    }
    
    [_accounts[accountIdx] stopAccount];
    [_accounts removeObjectAtIndex:accountIdx];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] removeAccount:accountIdx];
}

- (void)reloadAccount:(NSUInteger)accountIdx {
    NSAssert(accountIdx < _accounts.count, @"accountIdx %lu is out of bounds %lu", accountIdx, _accounts.count);
    
    SMUserAccount *account = (SMUserAccount*)_accounts[accountIdx];
    [account reloadAccount:accountIdx];
    
    [SMNotificationsController localNotifyAccountPreferencesChanged:account];
}

- (void)reconnectAccount:(NSUInteger)accountIdx {
    NSAssert(accountIdx < _accounts.count, @"accountIdx %lu is out of bounds %lu", accountIdx, _accounts.count);
    
    SMUserAccount *account = (SMUserAccount*)_accounts[accountIdx];

    [account initSession:accountIdx];
    [account getIMAPServerCapabilities];
    [account initOpExecutor];
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

- (NSUInteger)accountIndex:(SMUserAccount*)account {
    return [_accounts indexOfObject:account];
}

- (NSUInteger)accountIndexByName:(NSString*)accountName {
    for(NSUInteger i = 0; i < _accounts.count; i++) {
        SMUserAccount *account = _accounts[i];
        
        if([account.accountName isEqualToString:accountName]) {
            return i;
        }
    }
    
    return NSNotFound;
}

- (void)enableOrDisableAccountControls {
    BOOL enableElements = (_accounts.count != 0);

    _appController.composeMessageMenuItem.enabled = NO;

    _appController.messageListToolbarViewController.composeMessageButton.enabled = enableElements;
    _appController.messageListToolbarViewController.trashButton.enabled = enableElements;
//TODO        _appController.searchField.enabled = enableElements;
    _appController.composeMessageMenuItem.enabled = enableElements;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // Cleanly crash on uncaught exceptions, such as during actions.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    
    _window.titlebarAppearsTransparent = YES;

    [[_window windowController] setShouldCascadeWindows:NO];
    [_window setFrameAutosaveName:@"MainWindow"];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    if(hasVisibleWindows) {
        [_window orderFront:self];
        [[[NSApplication sharedApplication] keyWindow] orderFront:self];
    }
    else {
        [_window makeKeyAndOrderFront:self];
    }
    
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // This is necessary to keep the main window open when the application
    // is self relaunched.
    [NSApp activateIgnoringOtherApps:YES];

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

        // Sanity checks in case if preferences are corrupted in some way
        if(_currentAccountIdx == UNIFIED_ACCOUNT_IDX) {
            if(accountsCount > 1 && _preferencesController.shouldUseUnifiedMailbox) {
                _currentAccountIsUnified = YES;
            }
            else {
                _currentAccountIdx = 0;
            }
        }
        else if(_currentAccountIdx >= accountsCount) {
            _currentAccountIdx = 0;
        }
        
        [self enableOrDisableAccountControls];
    }

    [_appController.accountsViewController reloadAccountViews:YES];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
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
        SM_LOG_WARNING(@"cannot get path to app dir");
        
        appSupportDir = [NSURL fileURLWithPath:@"~/Library/Application Support/" isDirectory:YES];
    }
    
    return [appSupportDir URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
}

+ (NSURL*)imageCacheDir {
    NSURL *appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    return [appDataDir URLByAppendingPathComponent:[NSString stringWithFormat:@"ImageCache"] isDirectory:YES];
}

+ (NSURL*)draftTempDir {
    NSURL *appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    return [appDataDir URLByAppendingPathComponent:[NSString stringWithFormat:@"DraftTemp"] isDirectory:YES];
}

+ (NSURL*)systemTempDir {
    NSURL *appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");

    return [appDataDir URLByAppendingPathComponent:@"Temp" isDirectory:YES];
}

@end
