//
//  SMMessageThreadViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/2/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SMAbstractLocalFolder;

@class SMMessageThread;

@interface SMMessageThreadViewController : NSViewController

@property (readonly) id<SMAbstractLocalFolder> currentLocalFolder;
@property (readonly) SMMessageThread *currentMessageThread;

- (void)findContents:(NSString*)stringToFind matchCase:(Boolean)matchCase forward:(Boolean)forward;
- (void)removeFindContentsResults;

- (void)setMessageThread:(SMMessageThread*)messageThread selectedThreadsCount:(NSUInteger)selectedThreadsCount localFolder:(id<SMAbstractLocalFolder>)localFolder;
- (void)updateMessageThread;

- (void)setCellCollapsed:(Boolean)collapsed cellIndex:(NSUInteger)cellIndex;

- (void)collapseAll;
- (void)uncollapseAll;

- (void)scrollToPrevMessage;
- (void)scrollToNextMessage;

- (void)updateCellFrames;

- (void)messageThreadViewWillClose;

- (void)showFindContentsPanel;
- (void)hideFindContentsPanel;

- (void)addLabel:(NSString*)label;
- (void)removeLabel:(NSString*)label;

@end
