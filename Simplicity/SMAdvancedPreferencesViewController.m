//
//  SMAdvancedPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMDatabase.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMAdvancedPreferencesViewController.h"

@interface SMAdvancedPreferencesViewController ()

@property (weak) IBOutlet NSPopUpButton *localStorageSizeList;
@property (weak) IBOutlet NSPopUpButton *logLevelList;
@property (weak) IBOutlet NSButton *useMailTransportLogging;

@end

@implementation SMAdvancedPreferencesViewController {
    NSArray *_localStorageSizeNames;
    NSArray *_localStorageSizeValues;
    NSArray *_logLevelNames;
    NSArray *_logLevelValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Local storage size

    _localStorageSizeNames = @[@"Auto", @"500 Mb", @"1 Gb", @"2 Gb", @"5 Gb", @"10 Gb", @"50 Gb", @"100 Gb", @"200 Gb", @"500 Gb"];
    _localStorageSizeValues = @[@0, @500, @1000, @2000, @5000, @10000, @50000, @100000, @200000, @500000];
    
    [_localStorageSizeList removeAllItems];

    for(NSString *name in _localStorageSizeNames) {
        [_localStorageSizeList addItemWithTitle:name];
    }

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger localStorageSize = [[appDelegate preferencesController] localStorageSizeMb];
    NSUInteger localStorageSizeItem = [_localStorageSizeValues indexOfObject:[NSNumber numberWithUnsignedInteger:localStorageSize]];
    
    if(localStorageSizeItem == NSNotFound) {
        SM_LOG_ERROR(@"Bad localStorageSizeItem value %lu, using 0", localStorageSize);
        localStorageSizeItem = 0;
    }
    
    [_localStorageSizeList selectItemAtIndex:localStorageSizeItem];
    
    // Log level

    _logLevelNames = @[@"Fatal", @"Error", @"Warning", @"Info", @"Debug", @"Noise"];
    _logLevelValues = @[@SM_LOG_LEVEL_FATAL, @SM_LOG_LEVEL_ERROR, @SM_LOG_LEVEL_WARNING, @SM_LOG_LEVEL_INFO, @SM_LOG_LEVEL_DEBUG, @SM_LOG_LEVEL_NOISE];
    
    [_logLevelList removeAllItems];
    
    for(NSString *name in _logLevelNames) {
        [_logLevelList addItemWithTitle:name];
    }

    NSUInteger logLevel = [[appDelegate preferencesController] logLevel];
    NSUInteger logLevelItem = [_logLevelValues indexOfObject:[NSNumber numberWithUnsignedInteger:logLevel]];
    
    if(logLevelItem == NSNotFound) {
        SM_LOG_ERROR(@"Bad logLevelItem value %lu, using 0", logLevel);
        logLevelItem = 0;
    }
    
    [_logLevelList selectItemAtIndex:logLevelItem];
    
    // Mail transport log level
    
    if([appDelegate preferencesController].mailTransportLogLevel == 0) {
        _useMailTransportLogging.state = NSOffState;
    }
    else {
        _useMailTransportLogging.state = NSOnState;
    }
}

- (IBAction)localStorageSizeAction:(id)sender {
    NSUInteger item = _localStorageSizeList.indexOfSelectedItem;
    NSAssert(item < _localStorageSizeValues.count, @"bad item %lu", item);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].localStorageSizeMb = [_localStorageSizeValues[item] unsignedIntegerValue];
}

- (IBAction)logLevelAction:(id)sender {
    NSUInteger item = _logLevelList.indexOfSelectedItem;
    NSAssert(item < _logLevelValues.count, @"bad item %lu", item);

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].logLevel = [_logLevelValues[item] unsignedIntegerValue];
}

- (IBAction)useMailTransportLoggingAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].mailTransportLogLevel = (_useMailTransportLogging.state == NSOffState? 0 : 1);
}

@end
