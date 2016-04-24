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
#import "SMMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMAddressBookController.h"
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
        _imageRegistry = [[SMImageRegistry alloc] init];
        _accounts = [NSMutableArray array];
    }
    
    SM_LOG_DEBUG(@"app delegate initialized");
    
    return self;
}

- (BOOL)accountsExist {
    return _accounts.count != 0;
}

- (NSArray<SMUserAccount*>*)accounts {
    return _accounts;
}

- (SMUserAccount*)currentAccount {
    return _accounts[_currentAccountIdx];
}

- (void)setCurrentAccountIdx:(NSUInteger)currentAccountIdx {
    NSAssert(currentAccountIdx < _accounts.count, @"bad currentAccountIdx %lu", currentAccountIdx);
    
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

    if(_currentAccountIdx >= accountIdx && accountIdx != 0) {
        _currentAccountIdx--;
    }
    
    [_accounts[accountIdx] stopAccount];
    [_accounts removeObjectAtIndex:accountIdx];
    
    [[[[NSApplication sharedApplication] delegate] preferencesController] removeAccount:accountIdx];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    _window.titleVisibility = NSWindowTitleHidden;
    
    [[_window windowController] setShouldCascadeWindows:NO];
    [_window setFrameAutosaveName:@"MainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUInteger accountsCount = [_preferencesController accountsCount];
    
     if(accountsCount == 0) {
        [_appController showNewAccountWindow];
    }
    else {
        for(NSUInteger i = 0; i < accountsCount; i++) {
            [self addAccount];
        }

        _currentAccountIdx = 0; // TODO: restore from properties
    }
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
