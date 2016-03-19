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
    SMUserAccount *_account; // TODO
}

- (id)init {
    self = [ super init ];

    if(self) {
        _preferencesController = [[SMPreferencesController alloc] init];
        _account = [[SMUserAccount alloc] init];
        _account.model = [[SMSimplicityContainer alloc] initWithAccount:_account preferencesController:_preferencesController]; // TODO
        _attachmentStorage = [[SMAttachmentStorage alloc] init];
        _messageComparators = [[SMMessageComparators alloc] init];
        _addressBookController = [[SMAddressBookController alloc] init];
        _imageRegistry = [[SMImageRegistry alloc] init];
        _currentAccountIdx = 0; // TODO: restore from properties
    }
    
    SM_LOG_DEBUG(@"app delegate initialized");
    
    return self;
}

- (NSArray<SMUserAccount*>*)accounts {
    return @[_account];
}

- (SMUserAccount*)currentAccount {
    return self.accounts[_currentAccountIdx];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    _window.titleVisibility = NSWindowTitleHidden;
    
    [[_window windowController] setShouldCascadeWindows:NO];
    [_window setFrameAutosaveName:@"MainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
     if([_preferencesController accountsCount] == 0) {
        [_appController showNewAccountWindow];
    }
    else {
        NSArray<SMUserAccount*> *accounts = [self accounts];

        for(NSUInteger i = 0; i < accounts.count; i++) {
            SMUserAccount *account = accounts[i];
            
            [account.model initSession:i];
            [account.model getIMAPServerCapabilities];
            [account.model initOpExecutor];
        }
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
