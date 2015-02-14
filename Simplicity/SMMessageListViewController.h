//
//  SMMessageListViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMMessageListViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSButton *updateMessagesNowButton;
@property IBOutlet NSButton *loadMoreMessagesButton;
@property IBOutlet NSProgressIndicator *updatingMessagesProgressIndicator;
@property IBOutlet NSProgressIndicator *loadingMoreMessagesProgressIndicator;
@property IBOutlet NSTableView *messageListTableView;

- (IBAction)updateMessagesNow:(id)sender;
- (IBAction)loadMoreMessages:(id)sender;

- (void)reloadMessageList:(Boolean)preserveSelection;
- (void)messageHeadersSyncFinished:(Boolean)hasUpdates;

- (void)stopProgressIndicators;

@end
