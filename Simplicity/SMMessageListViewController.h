//
//  SMMessageListViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMFolder;

@interface SMMessageListViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *messageListTableView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

- (IBAction)toggleStarAction:(id)sender;
- (IBAction)toggleUnseenAction:(id)sender;

- (void)reloadMessageList:(Boolean)preserveSelection;
- (void)reloadMessageList:(Boolean)preserveSelection updateScrollPosition:(BOOL)updateScrollPosition;
- (void)messageHeadersSyncFinished:(Boolean)hasUpdates updateScrollPosition:(BOOL)updateScrollPosition;
- (void)moveSelectedMessageThreadsToFolder:(SMFolder*)remoteFolderName;

- (NSMenu*)menuForRow:(NSInteger)row;

@end
