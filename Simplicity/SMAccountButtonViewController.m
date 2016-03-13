//
//  SMAccountButtonViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/12/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMAccountButtonViewController.h"

@interface SMAccountButtonViewController ()

@end

@implementation SMAccountButtonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)reloadAccountInfo {
    NSString *accountImagePath = [[[[NSApplication sharedApplication] delegate] preferencesController] accountImagePath:_accountIdx];
    NSAssert(accountImagePath != nil, @"accountImagePath is nil");
    
    _accountImage.image = [[NSImage alloc] initWithContentsOfFile:accountImagePath];
    
    if([[[[NSApplication sharedApplication] delegate] preferencesController] shouldShowEmailAddressesInMailboxes]) {
        _accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] userEmail:_accountIdx];
    }
    else {
        _accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:_accountIdx];
    }
}

@end
