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
#import "SMSimplicityContainer.h"
#import "SMPreferencesController.h"
#import "SMAdvancedPreferencesViewController.h"

@interface SMAdvancedPreferencesViewController ()

@property (weak) IBOutlet NSPopUpButton *localStorageSizeList;

@end

@implementation SMAdvancedPreferencesViewController {
    NSArray *_localStorageSizeNames;
    NSArray *_localStorageSizeValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];

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
}

- (IBAction)localStorageSizeAction:(id)sender {
    NSUInteger item = _localStorageSizeList.indexOfSelectedItem;
    NSAssert(item < _localStorageSizeValues.count, @"bad item %lu", item);
    
    NSUInteger localStorageSizeMb = [_localStorageSizeValues[item] unsignedIntegerValue];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].localStorageSizeMb = [_localStorageSizeValues[item] unsignedIntegerValue];
    
    [[[appDelegate model] database] setFileSizeLimitMb:localStorageSizeMb];
}

@end
