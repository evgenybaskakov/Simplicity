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
#import "SMAbstractAccount.h"
#import "SMAbstractLocalFolder.h"
#import "SMAccountMailbox.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMailbox.h"
#import "SMImageRegistry.h"
#import "SMAddress.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMAccountImageSelection.h"
#import "SMColorView.h"
#import "SMFlippedView.h"
#import "SMLocalFolderRegistry.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageThreadViewController.h"
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
        _scrollView.drawsBackground = NO;
        _scrollView.borderType = NSNoBorder;
        _scrollView.hasVerticalScroller = YES;
        _scrollView.hasHorizontalScroller = NO;
        
        _contentView = [[SMFlippedView alloc] initWithFrame:_scrollView.frame];
        _contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        _scrollView.documentView = _contentView;
        
        _accountButtonViewControllers = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncError:) name:@"AccountSyncError" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncSuccess:) name:@"AccountSyncSuccess" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
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

- (BOOL)shouldShowUnifiedMailboxButton {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    return ([[appDelegate preferencesController] shouldUseUnifiedMailbox] && appDelegate.accounts.count > 1)? YES : NO;
}

- (void)reloadAccountViews:(BOOL)reloadControllers {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    const NSInteger accountCount = appDelegate.accounts.count;
    
    if(accountCount == 0) {
        SM_LOG_INFO(@"no accounts in the account properties");

        [_scrollView removeFromSuperview];

        return;
    }
    
    [_scrollView setFrame:NSMakeRect(0, 0, NSWidth(self.view.frame), NSHeight(self.view.frame))];
    [self.view addSubview:_scrollView];
    
    BOOL unifiedMailboxButtonShown = [self shouldShowUnifiedMailboxButton];
    
    if(reloadControllers) {
        [_accountButtonViewControllers removeAllObjects];

        for(NSInteger beginIdx = (unifiedMailboxButtonShown? -1 : 0), i = beginIdx; i < accountCount; i++) {
            SMAccountButtonViewController *accountButtonViewController = [[SMAccountButtonViewController alloc] initWithNibName:nil bundle:nil];
            NSAssert(accountButtonViewController.view, @"button.view");

            accountButtonViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
            
            if(i == -1) {
                accountButtonViewController.accountName.stringValue = @"Unified Mailbox";
                accountButtonViewController.accountImage.image = [appDelegate.imageRegistry unifiedAccountImage];
            }
            else {
                if([[appDelegate preferencesController] shouldShowEmailAddressesInMailboxes]) {
                    accountButtonViewController.accountName.stringValue = [appDelegate.accounts[i].accountAddress email];
                }
                else {
                    accountButtonViewController.accountName.stringValue = appDelegate.accounts[i].accountName;
                }

                accountButtonViewController.accountImage.image = appDelegate.accounts[i].accountImage;
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
            
            accountButtonViewController.accountButton.action = @selector(accountButtonAction:);
            accountButtonViewController.accountButton.target = self;
            accountButtonViewController.accountButton.tag = i;
            accountButtonViewController.accountIdx = i;
            
            [_accountButtonViewControllers addObject:accountButtonViewController];
        }
    }
    
    [_contentView setSubviews:@[]];
    
    NSView *prevView = nil;
    for(NSUInteger i = 0; i < _accountButtonViewControllers.count; i++) {
        if(i != 0) {
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

        BOOL mailboxExpanded = NO;
        if(unifiedMailboxButtonShown) {
            if(i == 0 && appDelegate.currentAccountIsUnified) {
                mailboxExpanded = YES;
            }
            else if(i != 0 && !appDelegate.currentAccountIsUnified) {
                const NSInteger accountIdx = (NSInteger)i - 1;
                
                if(accountIdx == appDelegate.currentAccountIdx) {
                    mailboxExpanded = YES;
                }
            }
        }
        else {
            if(i == appDelegate.currentAccountIdx) {
                mailboxExpanded = YES;
            }
        }
        
        if(mailboxExpanded) {
            _accountButtonViewControllers[i].trackMouse = NO;

            NSView *mailboxView = [[[appDelegate appController] mailboxViewController] view];
            mailboxView.translatesAutoresizingMaskIntoConstraints = NO;

            [_contentView addSubview:mailboxView];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
            
            [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:mailboxView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
            
            prevView = mailboxView;
        }
        else {
            _accountButtonViewControllers[i].trackMouse = YES;

            prevView = buttonView;
        }
    }
    
    [_contentView addConstraint:[NSLayoutConstraint constraintWithItem:_contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:prevView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    
    for(NSInteger i = 0; i < accountCount; i++) {
        [self updateAccountButtonInfo:i];
    }
    
    [self updateUnifiedAccountButtonInfo];
}

- (void)changeAccountTo:(NSInteger)accountIdx {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = appDelegate.appController;

    BOOL updateViewControllers = NO;
    
    if(accountIdx == UNIFIED_ACCOUNT_IDX) {
        if(!appDelegate.currentAccountIsUnified) {
            [appController clearSearch:YES cancelFocus:YES];
            [appDelegate setCurrentAccount:appDelegate.unifiedAccount];
            
            updateViewControllers = YES;
        }
    }
    else {
        if(appDelegate.currentAccountIsUnified || appDelegate.currentAccountIdx != accountIdx) {
            SM_LOG_INFO(@"switching to account %lu", accountIdx);

            [appController clearSearch:YES cancelFocus:YES];
            [appDelegate setCurrentAccount:appDelegate.accounts[accountIdx]];

            updateViewControllers = YES;
        }
    }
    
    if(updateViewControllers) {
        [appController updateMailboxFolderListForAccount:appDelegate.currentAccount];
        [[appController operationQueueWindowController] reloadOperationQueue];
        [[appController messageListViewController] reloadMessageList:YES updateScrollPosition:YES];
        [[appController messageThreadViewController] updateMessageThread];
        
        [self reloadAccountViews:NO];
    }
}

- (void)accountButtonAction:(id)sender {
    NSInteger clickedAccountIdx = [(NSButton*)sender tag];
    
    [self changeAccountTo:clickedAccountIdx];
}

- (NSUInteger)accountIdxToAccountButtonIdx:(NSUInteger)accountIdx {
    if([self shouldShowUnifiedMailboxButton]) {
        return accountIdx + 1;
    }
    
    return accountIdx;
}

- (void)accountSyncError:(NSNotification*)notification {
    NSError *error;
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncErrorParams:notification error:&error account:&account];
    
    NSAssert(account != nil, @"account is nil");
    NSAssert(error != nil, @"error is nil");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSUInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    if(accountIdx != NSNotFound) {
        NSUInteger buttonIdx = [self accountIdxToAccountButtonIdx:accountIdx];
        [_accountButtonViewControllers[buttonIdx] showAttention:error.localizedDescription];
    }
    else {
        SM_LOG_ERROR(@"account %@ not found", account);
    }
}

- (void)accountSyncSuccess:(NSNotification*)notification {
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncSuccessParams:notification account:&account];
    
    NSAssert(account != nil, @"account is nil");
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSUInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    if(accountIdx != NSNotFound) {
        NSUInteger buttonIdx = [self accountIdxToAccountButtonIdx:accountIdx];
        [_accountButtonViewControllers[buttonIdx] hideAttention];
    }
    else {
        SM_LOG_ERROR(@"account %@ not found", account);
    }
}

- (void)messagesUpdated:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessagesUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    if(accountIdx != NSNotFound) {
        [self updateAccountButtonInfo:accountIdx];
    }

    [self updateUnifiedAccountButtonInfo];
}

- (void)updateAccountButtonInfo:(NSInteger)accountIdx {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMUserAccount *account = appDelegate.accounts[accountIdx];
    
    NSUInteger buttonIdx = [self accountIdxToAccountButtonIdx:accountIdx];
    
    SMFolder *inboxFolder = [[account mailbox] inboxFolder];
    id<SMAbstractLocalFolder> inboxLocalFolder = [account.localFolderRegistry getLocalFolderByName:inboxFolder.fullName];
    
    NSString *unreadCountStr = @"";
    if(appDelegate.currentAccount != account) {
        if(inboxLocalFolder && inboxLocalFolder.unseenMessagesCount > 0) {
            unreadCountStr = [NSString stringWithFormat:@"%lu", inboxLocalFolder.unseenMessagesCount];
        }
    }
    
    [_accountButtonViewControllers[buttonIdx].unreadCountField setStringValue:unreadCountStr];
}

- (void)updateUnifiedAccountButtonInfo {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    NSString *unreadCountStr = @"";
    if([self shouldShowUnifiedMailboxButton] && !appDelegate.currentAccountIsUnified) {
        SMUnifiedAccount *unifiedAccount = appDelegate.unifiedAccount;
        SMFolder *inboxFolder = [unifiedAccount.mailbox inboxFolder];
        id<SMAbstractLocalFolder> inboxLocalFolder = [unifiedAccount.localFolderRegistry getLocalFolderByName:inboxFolder.fullName];
        
        if(inboxLocalFolder && inboxLocalFolder.unseenMessagesCount > 0) {
            unreadCountStr = [NSString stringWithFormat:@"%lu", inboxLocalFolder.unseenMessagesCount];
        }
    }

    [_accountButtonViewControllers[0].unreadCountField setStringValue:unreadCountStr];
}

@end
