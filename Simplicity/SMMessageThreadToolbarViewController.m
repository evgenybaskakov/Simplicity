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

    [_searchFieldView addConstraint:[NSLayoutConstraint constraintWithItem:_searchFieldView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_searchFieldViewController.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    
    [_searchFieldView addConstraint:[NSLayoutConstraint constraintWithItem:_searchFieldView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_searchFieldViewController.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    
    [_searchFieldView addConstraint:[NSLayoutConstraint constraintWithItem:_searchFieldView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_searchFieldViewController.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
    
    //containerView.topAnchor.constraintEqualToAnchor(topLayoutGuide.bottomAnchor, constant: 8.0).active = true
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = appDelegate.appController;
    
    _searchFieldViewController.target = appController;
    _searchFieldViewController.action = @selector(searchUsingToolbarSearchField:);
    _searchFieldViewController.actionDelay = 0.2;
    _searchFieldViewController.cancelAction = @selector(cancelSearchUsingToolbarSearchField:);
    _searchFieldViewController.clearAction = @selector(clearSearchUsingToolbarSearchField:);
    _searchFieldViewController.enterAction = @selector(enterSearchUsingToolbarSearchField:);
    _searchFieldViewController.arrowUpAction = @selector(searchMenuCursorUp:);
    _searchFieldViewController.arrowDownAction = @selector(searchMenuCursorDown:);
}

- (IBAction)messageNavigationAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
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
