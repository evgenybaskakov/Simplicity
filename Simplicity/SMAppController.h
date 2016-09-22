//
//  SMAppController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "SMAbstractAccount.h"

@protocol SMAbstractLocalFolder;

@class SMMessageListToolbarViewController;
@class SMTokenFieldViewController;
@class SMSectionMenuViewController;
@class SMNewAccountWindowController;
@class SMPreferencesWindowController;
@class SMMailboxViewController;
@class SMMessageListViewController;
@class SMAccountsViewController;
@class SMMessageThreadViewController;
@class SMInstrumentPanelViewController;
@class SMNewLabelWindowController;
@class SMMessageEditorWindowController;
@class SMOperationQueueWindowController;
@class SMMessageWindowController;
@class SMMessageThread;
@class SMSearchRequestInputController;
@class SMUserAccount;

typedef NS_ENUM(NSUInteger, SMSearchOperationKind) {
    SMSearchOperationKind_Suggestions,
    SMSearchOperationKind_Content,
};

@interface SMAppController : NSObject <NSToolbarDelegate, NSSplitViewDelegate, NSWindowDelegate>

@property (weak, nonatomic) IBOutlet NSView *view;

@property (nonatomic) IBOutlet NSSegmentedControl *messageNavigationControl;
@property (weak) IBOutlet NSToolbarItem *searchFieldToolbarItem;

@property (weak) IBOutlet NSMenuItem *composeMessageMenuItem;
@property (weak) IBOutlet NSMenuItem *textFormatMenuItem;
@property (weak) IBOutlet NSMenuItem *htmlTextFormatMenuItem;
@property (weak) IBOutlet NSMenuItem *plainTextFormatMenuItem;

- (IBAction)composeMessageAction:(id)sender;
- (IBAction)moveToTrashAction:(id)sender;
- (IBAction)toggleFindContentsPanelAction:(id)sender;
- (IBAction)toggleSearchMailboxPanelAction:(id)sender;
- (IBAction)messageNavigationAction:(id)sender;

@property SMTokenFieldViewController *searchFieldViewController;
@property SMSectionMenuViewController *searchMenuViewController;
@property SMAccountsViewController *accountsViewController;
@property SMMailboxViewController *mailboxViewController;
@property SMMessageListViewController *messageListViewController;
@property SMMessageThreadViewController *messageThreadViewController;
@property SMInstrumentPanelViewController *instrumentPanelViewController;
@property SMMessageListToolbarViewController *messageListToolbarViewController;

- (void)updateMailboxFolderListForAccount:(id<SMAbstractAccount>)account;

@property (nonatomic) SMNewLabelWindowController *addNewLabelWindowController;

- (void)showNewLabelSheet:(NSString*)suggestedParentFolder;
- (void)hideNewLabelSheet;

@property (nonatomic) SMOperationQueueWindowController *operationQueueWindowController;

- (void)toggleOperationQueueSheet;
- (void)hideOperationQueueSheet;

- (void)openMessageWindow:(SMMessageThread*)messageThread localFolder:(id<SMAbstractLocalFolder>)localFolder;
- (void)openMessageEditorWindow:(NSString*)textContent plainText:(Boolean)plainText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments;

- (void)closeMessageEditorWindow:(SMMessageEditorWindowController*)messageEditorWindowController;

- (void)moveSelectedMessageThreadsToTrash;

@property (nonatomic) SMPreferencesWindowController *preferencesWindowController;

- (BOOL)preferencesWindowShown;
- (void)hidePreferencesWindow;

@property (nonatomic) SMNewAccountWindowController *createNewAccountWindowController;

- (void)showNewAccountWindow;
- (void)closeNewAccountWindow;

@property (readonly, nonatomic) SMSearchRequestInputController *searchRequestInputController;
@property (readonly, nonatomic) NSWindow *searchSuggestionsMenu;

- (void)closeSearchSuggestionsMenu;
- (void)adjustSearchSuggestionsMenuFrame;
- (void)startNewSearch:(BOOL)showSuggestionsMenu;
- (void)finishSearch:(SMSearchOperationKind)searchOperationKind;
- (void)clearSearch:(BOOL)changeToPrevFolder cancelFocus:(BOOL)cancelFocus;

- (void)enableMessageThreadNavigationControl;
- (void)disableMessageThreadNavigationControl;

@property (nonatomic, readonly) BOOL messageWindowsOpened;

- (void)closeMessageWindow:(SMMessageWindowController*)messageWindowController;

@end
