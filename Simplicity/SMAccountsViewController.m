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
#import "SMNotificationsController.h"
#import "SMColorView.h"
#import "SMFlippedView.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMOperationQueueWindowController.h"
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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncError:) name:@"AccountSyncError" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncSuccess:) name:@"FolderListUpdated" object:nil];
    }
    
    return self;
}

- (void)setMailboxTheme:(SMMailboxTheme)mailboxTheme {
    NSVisualEffectView *rootView = (NSVisualEffectView*)self.view;
    
    rootView.state = NSVisualEffectStateActive;
    rootView.blendingMode = NSVisualEffectBlendingModeBehindWindow;

    NSVisualEffectMaterial material = NSVisualEffectMaterialDark;
    switch(mailboxTheme) {
        case SMMailboxTheme_Light:
            material = NSVisualEffectMaterialLight;
            break;
        case SMMailboxTheme_MediumLight:
            material = NSVisualEffectMaterialMediumLight;
            break;
        case SMMailboxTheme_MediumDark:
            material = NSVisualEffectMaterialDark;
            break;
        case SMMailboxTheme_Dark:
            material = NSVisualEffectMaterialUltraDark;
            break;
        default:
            SM_LOG_ERROR(@"unknown theme %lu", mailboxTheme);
    }
    
    rootView.material = material;
    
    [self reloadAccountViews:NO];
}

- (void)reloadAccountViews:(BOOL)reloadControllers {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    if(reloadControllers) {
        [_accountButtonViewControllers removeAllObjects];

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
            
            NSColor *color = [NSColor whiteColor];
            switch([[appDelegate preferencesController] mailboxTheme]) {
                case SMMailboxTheme_Light:
                    color = [NSColor blackColor];
                    break;
                    
                case SMMailboxTheme_MediumLight:
                    color = [NSColor blackColor];
                    break;
                    
                case SMMailboxTheme_MediumDark:
                    color = [NSColor whiteColor];
                    break;
                    
                case SMMailboxTheme_Dark:
                    color = [NSColor colorWithCalibratedWhite:0.9 alpha:1.0];
                    break;
            }
            
            [accountButtonViewController.accountName setTextColor:color];
            
            NSString *accountImagePath = [[[[NSApplication sharedApplication] delegate] preferencesController] accountImagePath:i];
            NSAssert(accountImagePath != nil, @"accountImagePath is nil");
            
            accountButtonViewController.accountImage.image = [[NSImage alloc] initWithContentsOfFile:accountImagePath];
            
            accountButtonViewController.accountButton.action = @selector(accountButtonAction:);
            accountButtonViewController.accountButton.target = self;
            accountButtonViewController.accountButton.tag = i;

            accountButtonViewController.accountIdx = i;
            
            [_accountButtonViewControllers addObject:accountButtonViewController];
        }
    }
    
    [_contentView setSubviews:@[]];
    
    NSAssert(_accountButtonViewControllers.count > 0, @"_accountButtonViewControllers.count == 0");
    
    NSView *prevView = nil;
    for(NSUInteger i = 0; i < _accountButtonViewControllers.count; i++) {
        if(i > 0) {
            NSColor *separatorColor = [NSColor whiteColor];
            switch([[appDelegate preferencesController] mailboxTheme]) {
                case SMMailboxTheme_Light:
                    separatorColor = [NSColor blackColor];
                    break;
                    
                case SMMailboxTheme_MediumLight:
                    separatorColor = [NSColor blackColor];
                    break;
                    
                case SMMailboxTheme_MediumDark:
                    separatorColor = [NSColor whiteColor];
                    break;
                    
                case SMMailboxTheme_Dark:
                    separatorColor = [NSColor colorWithCalibratedWhite:0.9 alpha:1.0];
                    break;
            }
            
            SMColorView *separatorView = [[SMColorView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
            separatorView.translatesAutoresizingMaskIntoConstraints = NO;
            separatorView.backgroundColor = [separatorColor colorWithAlphaComponent:0.5];
            
            [_contentView addSubview:separatorView];

            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:separatorView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:1]];

            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:separatorView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:separatorView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:prevView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:separatorView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];

            prevView = separatorView;
        }
        
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

        NSColor *buttonColor = [NSColor whiteColor];
        switch([[appDelegate preferencesController] mailboxTheme]) {
            case SMMailboxTheme_Light:
                buttonColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
                break;
                
            case SMMailboxTheme_MediumLight:
                buttonColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
                break;
                
            case SMMailboxTheme_MediumDark:
                buttonColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
                break;
                
            case SMMailboxTheme_Dark:
                buttonColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
                break;
        }
        
        _accountButtonViewControllers[i].backgroundColor = buttonColor;

        if(i == appDelegate.currentAccountIdx) {
            _accountButtonViewControllers[i].trackMouse = NO;
        }
        else {
            _accountButtonViewControllers[i].trackMouse = YES;
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

- (void)changeAccountTo:(NSUInteger)accountIdx {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(appDelegate.currentAccountIdx != accountIdx) {
        SM_LOG_INFO(@"switching to account %lu", accountIdx);

        appDelegate.currentAccountIdx = accountIdx;
        
        [[appDelegate appController] updateMailboxFolderListForAccount:appDelegate.currentAccount];
        [[[appDelegate appController] operationQueueWindowController] reloadOperationQueue];

        [[[appDelegate currentAccount] messageListController] updateMessageList];
        
        [self reloadAccountViews:NO];
    }
}

- (void)accountButtonAction:(id)sender {
    NSUInteger clickedAccountIdx = [(NSButton*)sender tag];
    
    [self changeAccountTo:clickedAccountIdx];
}

- (void)accountSyncError:(NSNotification*)notification {
    NSString *error;
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncErrorParams:notification error:&error account:&account];
    
    NSAssert(account != nil, @"account is nil");
    NSAssert(error != nil, @"error is nil");

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    if(accountIdx != NSNotFound) {
        [_accountButtonViewControllers[accountIdx] showAttention:error];
    }
    else {
        SM_LOG_ERROR(@"account %@ not found", account);
    }
}

- (void)accountSyncSuccess:(NSNotification*)notification {
    SMUserAccount *account;
    
    [SMNotificationsController getFolderListUpdatedParams:notification account:&account];
    
    NSAssert(account != nil, @"account is nil");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    if(accountIdx != NSNotFound) {
        [_accountButtonViewControllers[accountIdx] hideAttention];
    }
    else {
        SM_LOG_ERROR(@"account %@ not found", account);
    }
}

@end
