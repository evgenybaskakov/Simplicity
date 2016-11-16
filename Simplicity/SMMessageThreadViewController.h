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
@class SMMessageEditorViewController;

@interface SMMessageThreadViewController : NSViewController

@property (readonly) id<SMAbstractLocalFolder> currentLocalFolder;
@property (readonly) SMMessageThread *currentMessageThread;

@property CGFloat topOffset;

- (void)findContents:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward;
- (void)removeFindContentsResults;

- (void)setMessageThread:(SMMessageThread*)messageThread selectedThreadsCount:(NSUInteger)selectedThreadsCount localFolder:(id<SMAbstractLocalFolder>)localFolder;
- (void)updateMessageThread;

- (void)setCellCollapsed:(BOOL)collapsed cellIndex:(NSUInteger)cellIndex;

- (void)collapseAll;
- (void)uncollapseAll;

- (void)scrollToPrevMessage;
- (void)scrollToNextMessage;

- (void)updateCellFrames;

- (void)messageThreadViewWillClose;

- (void)showFindContentsPanel:(BOOL)replace;
- (void)hideFindContentsPanel;

- (void)addLabel:(NSString*)label;
- (void)removeLabel:(NSString*)label;

- (void)closeEmbeddedEditorWithoutSavingDraft;

- (void)makeEditorWindow:(SMMessageEditorViewController*)messageEditorViewController;

@end
