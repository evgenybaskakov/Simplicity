//
//  SMUnifiedSearchResultsController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/25/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMUnifiedSearchResultsController.h"

@implementation SMUnifiedSearchResultsController

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self != nil) {

    }
    
    return self;
}

- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    BOOL result = NO;
    for(SMUserAccount *account in appDelegate.accounts) {
        if([[account searchResultsController] startNewSearchWithPattern:searchPattern]) {
            result = YES;
        }
    }
    
    return result;
}

- (void)stopLatestSearch {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    for(SMUserAccount *account in appDelegate.accounts) {
        [[account searchResultsController] stopLatestSearch];
    }
}

@end
