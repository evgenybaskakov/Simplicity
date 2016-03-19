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
#import "SMPreferencesController.h"
#import "SMFlippedView.h"
#import "SMMailboxViewController.h"
#import "SMAccountButtonViewController.h"
#import "SMAccountsViewController.h"

@implementation SMAccountsViewController {
    NSMutableArray<SMAccountButtonViewController*> *_accountButtonViewControllers;
    NSScrollView *_scrollView;
    NSView *_contentView;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        NSVisualEffectView *rootView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        rootView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        rootView.state = NSVisualEffectStateActive;
        rootView.material = NSVisualEffectMaterialUltraDark;
        rootView.blendingMode = NSVisualEffectBlendingModeBehindWindow;

        [self setView:rootView];

        _scrollView = [[NSScrollView alloc] initWithFrame:rootView.frame];
        _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _scrollView.backgroundColor = [NSColor clearColor];
        _scrollView.borderType = NSNoBorder;
        _scrollView.hasVerticalScroller = YES;
        _scrollView.hasHorizontalScroller = NO;
        
        [rootView addSubview:_scrollView];
        
        _contentView = [[SMFlippedView alloc] initWithFrame:_scrollView.frame];
        _contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _scrollView.documentView = _contentView;
        
        _accountButtonViewControllers = [NSMutableArray array];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.
    
}

- (void)reloadAccounts {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    [_accountButtonViewControllers removeAllObjects];
    [_contentView setSubviews:@[]];

    for(NSUInteger i = 0; i < [[appDelegate preferencesController] accountsCount]; i++) {
        SMAccountButtonViewController *accountButtonViewController = [[SMAccountButtonViewController alloc] initWithNibName:nil bundle:nil];
        NSAssert(accountButtonViewController.view, @"button.view");

        accountButtonViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
        accountButtonViewController.accountName.stringValue = [[appDelegate preferencesController] accountName:i];
        
        if([[[[NSApplication sharedApplication] delegate] preferencesController] shouldShowEmailAddressesInMailboxes]) {
            accountButtonViewController.accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] userEmail:i];
        }
        else {
            accountButtonViewController.accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:i];
        }
        
        NSString *accountImagePath = [[[[NSApplication sharedApplication] delegate] preferencesController] accountImagePath:i];
        NSAssert(accountImagePath != nil, @"accountImagePath is nil");
        
        accountButtonViewController.accountImage.image = [[NSImage alloc] initWithContentsOfFile:accountImagePath];
        
        accountButtonViewController.accountButton.action = @selector(accountButtonAction:);
        accountButtonViewController.accountButton.target = self;
        accountButtonViewController.accountButton.tag = i;

        accountButtonViewController.accountIdx = i;

        [_accountButtonViewControllers addObject:accountButtonViewController];
    }
    
    NSAssert(_accountButtonViewControllers.count > 0, @"_accountButtonViewControllers.count == 0");
    
    NSView *prevView = nil;
    for(NSUInteger i = 0; i < _accountButtonViewControllers.count; i++) {
        NSView *buttonView = _accountButtonViewControllers[i].view;
        
        [_contentView addSubview:buttonView];
        
        [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:buttonView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
        
        [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:buttonView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];

        if(i == 0) {
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:buttonView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        }
        else {
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:prevView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:buttonView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        }
        
        if(i == appDelegate.currentAccountIdx) {
            NSView *mailboxView = [appController.mailboxViewController view];
            mailboxView.translatesAutoresizingMaskIntoConstraints = NO;

            [_contentView addSubview:mailboxView];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
            
            prevView = mailboxView;
        }
        else {
            prevView = buttonView;
        }
    }
    
    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:prevView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
}

- (void)accountButtonAction:(id)sender {
    NSUInteger clickedAccountIdx = [(NSButton*)sender tag];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(appDelegate.currentAccountIdx != clickedAccountIdx) {
        SM_LOG_INFO(@"switching to account %lu", clickedAccountIdx);
        
        appDelegate.currentAccountIdx = clickedAccountIdx;
        
        [self reloadAccounts];
    }
}

@end
