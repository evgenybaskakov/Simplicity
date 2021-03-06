//
//  SMMessageThreadToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMessageThreadViewController.h"
#import "SMTokenFieldViewController.h"
#import "SMMessageThreadToolbarViewController.h"

@interface SMMessageThreadToolbarViewController ()

@end

@implementation SMMessageThreadToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _searchFieldViewController = [[SMTokenFieldViewController alloc] initWithNibName:@"SMTokenFieldViewController" bundle:nil];
    NSAssert(_searchFieldViewController.view != nil, @"_searchFieldViewController is nil");
    
    _searchFieldView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchFieldViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_searchFieldView addSubview:_searchFieldViewController.view];

    [_searchFieldView.leadingAnchor constraintEqualToAnchor:_searchFieldViewController.view.leadingAnchor constant:0].active = true;
    [_searchFieldView.trailingAnchor constraintEqualToAnchor:_searchFieldViewController.view.trailingAnchor constant:0].active = true;
    [_searchFieldView.centerYAnchor constraintEqualToAnchor:_searchFieldViewController.view.centerYAnchor constant:0].active = true;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = appDelegate.appController;
    
    _searchFieldViewController.target = appController;
    _searchFieldViewController.action = @selector(searchUsingToolbarSearchField:);
    _searchFieldViewController.actionDelay = 0.2;
    _searchFieldViewController.cancelAction = @selector(cancelSearchUsingToolbarSearchField:);
    _searchFieldViewController.clearAction = @selector(clearSearchUsingToolbarSearchField:);
    _searchFieldViewController.enterAction = @selector(enterSearchUsingToolbarSearchField:);
    _searchFieldViewController.arrowUpAction = @selector(searchMenuCursorUp:);
    _searchFieldViewController.arrowDownAction = @selector(searchMenuCursorDown:);

    for(NSSegmentedControl *control in @[_messageNavigationControl]) {
        for(NSUInteger i = 0; i < control.segmentCount; i++) {
            NSImage *img = [control imageForSegment:i];
            NSSize buttonSize = [[control cell] cellSize];
            [img setSize:NSMakeSize(buttonSize.height/1.8, buttonSize.height/1.8)];
            [control setImage:img forSegment:i];
        }
    }
}

- (void)scaleImage:(NSButton*)button {
    NSImage *img = [button image];
    NSSize buttonSize = [[button cell] cellSize];
    [img setSize:NSMakeSize(buttonSize.height/1.8, buttonSize.height/1.8)];
    [button setImage:img];
}

- (IBAction)messageNavigationAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    switch(_messageNavigationControl.selectedSegment) {
        case 0:
            [[[appDelegate appController] messageThreadViewController] scrollToPrevMessage];
            break;
        case 1:
            [[[appDelegate appController] messageThreadViewController] scrollToNextMessage];
            break;
        case 2:
            [[[appDelegate appController] messageThreadViewController] collapseAll];
            break;
        case 3:
            [[[appDelegate appController] messageThreadViewController] uncollapseAll];
            break;
    }
}

@end
