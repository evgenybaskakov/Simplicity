//
//  SMInstrumentPanelViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/26/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMInstrumentPanelViewController.h"

@implementation SMInstrumentPanelViewController

- (IBAction)hideSearchResults:(id)sender {
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	SMAppController *appController = [appDelegate appController];

	[appController toggleSearchResultsView];
}

- (IBAction)addNewLabel:(id)sender {
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	SMAppController *appController = [appDelegate appController];

	[appController showNewLabelSheet:nil];
}

- (IBAction)showOperationQueue:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];

    [appController showOperationQueueSheet];
}

@end
