//
//  SMMessageListViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMFolder;
@class SMMessageThread;

@interface SMMessageListViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *messageListTableView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

- (IBAction)toggleStarAction:(id)sender;
- (IBAction)toggleUnseenAction:(id)sender;

- (void)toggleStarForSelected;
- (void)unselectCurrentMessageThread;
- (void)selectMessageThread:(SMMessageThread*)messageThread;
- (void)reloadMessageList:(BOOL)preserveSelection;
- (void)reloadMessageList:(BOOL)preserveSelection updateScrollPosition:(BOOL)updateScrollPosition;
- (void)messageHeadersSyncFinished:(BOOL)hasUpdates updateScrollPosition:(BOOL)updateScrollPosition;
- (void)moveSelectedMessageThreadsToFolder:(SMFolder*)remoteFolderName;
- (void)showLoadProgress;
- (void)hideLoadProgress;

- (NSMenu*)menuForRow:(NSInteger)row;

@end
