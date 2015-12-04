//
//  SMSearchResultsListCellView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMSearchResultsListViewController.h"
#import "SMSearchResultsListCellView.h"

@implementation SMSearchResultsListCellView

- (IBAction)removeSearch:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMSearchResultsListViewController *searchResultsListViewController = [[appDelegate appController] searchResultsListViewController];
    
    [searchResultsListViewController removeSearch:[_searchResultsListRow integerValue]];
}

- (IBAction)reloadSearch:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMSearchResultsListViewController *searchResultsListViewController = [[appDelegate appController] searchResultsListViewController];
    
    [searchResultsListViewController reloadSearch:[_searchResultsListRow integerValue]];
}

- (IBAction)stopSearch:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMSearchResultsListViewController *searchResultsListViewController = [[appDelegate appController] searchResultsListViewController];
    
    [searchResultsListViewController stopSearch:[_searchResultsListRow integerValue]];
}

@end
