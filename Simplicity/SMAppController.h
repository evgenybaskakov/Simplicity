//
//  SMAppController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class SMMailboxViewController;
@class SMSearchResultsListViewController;
@class SMMessageListViewController;
@class SMMessageViewController;
@class SMMessageThreadViewController;
@class SMInstrumentPanelViewController;
@class SMFolderColorController;
@class SMNewLabelWindowController;
@class SMMessageEditorWindowController;
@class SMOperationQueueWindowController;
@class SMOutboxController;
@class SMOperationExecutor;

@interface SMAppController : NSObject <NSToolbarDelegate, NSSplitViewDelegate>

@property (weak, nonatomic) IBOutlet NSView *view;

@property (nonatomic) IBOutlet NSToolbar *toolbar;
@property (nonatomic) IBOutlet NSButton *composeMessageButton;
@property (nonatomic) IBOutlet NSButton *trashButton;
@property (nonatomic) IBOutlet NSTextField *searchField;

- (IBAction)trashAction:(id)sender;
- (IBAction)toggleFindContentsPanelAction:(id)sender;

@property SMMailboxViewController *mailboxViewController;
@property SMSearchResultsListViewController *searchResultsListViewController;
@property SMMessageListViewController *messageListViewController;
@property SMMessageThreadViewController *messageThreadViewController;
@property SMInstrumentPanelViewController *instrumentPanelViewController;
@property SMFolderColorController *folderColorController;
@property SMOutboxController *outboxController;
@property SMOperationExecutor *operationExecutor;

- (void)updateMailboxFolderListView;
- (void)toggleSearchResultsView;

- (void)showFindContentsPanel;
- (void)hideFindContentsPanel;

@property (nonatomic) SMNewLabelWindowController *addNewLabelWindowController;

- (void)showNewLabelSheet:(NSString*)suggestedParentFolder;
- (void)hideNewLabelSheet;

@property (nonatomic) SMOperationQueueWindowController *operationQueueWindowController;

- (void)showOperationQueueSheet;
- (void)hideOperationQueueSheet;

- (void)closeMessageEditorWindow:(SMMessageEditorWindowController*)messageEditorWindowController;

@end
