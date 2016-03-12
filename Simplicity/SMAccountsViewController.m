//
//  SMAccountsViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/11/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMFlippedView.h"
#import "SMMailboxViewController.h"
#import "SMAccountsViewController.h"

@implementation SMAccountsViewController {
    NSMutableArray<NSView*> *_accountCells;
    NSScrollView *_scrollView;
    NSView *_contentView;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _scrollView = [[NSScrollView alloc] init];
        
        [_scrollView setBorderType:NSNoBorder];
        [_scrollView setHasVerticalScroller:YES];
        [_scrollView setHasHorizontalScroller:NO];
        [_scrollView setTranslatesAutoresizingMaskIntoConstraints:NO];
        
        [self setView:_scrollView];
        
        _contentView = [[SMFlippedView alloc] initWithFrame:_scrollView.frame];
        _contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        [_scrollView setDocumentView:_contentView];
        
        _accountCells = [NSMutableArray new];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.
    
}

- (void)reloadAccounts {
    [_accountCells removeAllObjects];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController.mailboxViewController reloadAccountInfo];

    NSView *mailboxView = [appController.mailboxViewController view];
    mailboxView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_accountCells addObject:mailboxView];

    [_contentView addSubview:mailboxView];

    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];

    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
    
    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    
    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
}

@end
