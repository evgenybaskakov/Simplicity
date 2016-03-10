//
//  SMAppDelegate.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMPreferencesController.h"
#import "SMMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMImageRegistry.h"
#import "SMAppController.h"
#import "SMAppDelegate.h"

@implementation SMAppDelegate

- (id)init {
    self = [ super init ];

    if(self) {
        _preferencesController = [[SMPreferencesController alloc] init];
        _model = [[SMSimplicityContainer alloc] initWithPreferencesController:_preferencesController];
        _imageRegistry = [[SMImageRegistry alloc] init];
        _currentAccount = 0; // TODO: restore from properties
    }
    
    SM_LOG_DEBUG(@"app delegate initialized");
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _window.titleVisibility = NSWindowTitleHidden;

    [[_window windowController] setShouldCascadeWindows:NO];
    [_window setFrameAutosaveName:@"MainWindow"];
    
    if([_preferencesController accountsCount] == 0) {
        [_appController showNewAccountWindow];
    }
    else {
        [_model initAccountSession:_currentAccount];
        [_model getIMAPServerCapabilities];
        
        [_appController initOpExecutor];
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
