//
//  SMAppController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMessageEditorWindowController.h"
#import "SMNewLabelWindowController.h"
#import "SMMailboxViewController.h"
#import "SMSearchResultsListController.h"
#import "SMSearchResultsListViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMInstrumentPanelViewController.h"
#import "SMFindContentsPanelViewController.h"
#import "SMOperationQueueWindowController.h"
#import "SMFolderColorController.h"
#import "SMOutboxController.h"
#import "SMOperationExecutor.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMMessageThread.h"
#import "SMMessageWindowController.h"

static NSString *SearchDocToolbarItemIdentifier = @"Search Item Identifier";
static NSString *ComposeMessageToolbarItemIdentifier = @"Compose Message Item Identifier";
static NSString *TrashToolbarItemIdentifier = @"Trash Item Identifier";

@implementation SMAppController {
	NSButton *button1, *button2;
	NSToolbarItem *__weak _activeSearchItem;
	NSLayoutConstraint *_searchResultsHeightConstraint;
	NSArray *_searchResultsShownConstraints;
	SMFindContentsPanelViewController *_findContentsPanelViewController;
	NSMutableArray *_findContentsPanelConstraints;
	Boolean _findContentsPanelShown;
	NSView *_messageThreadAndFindContentsPanelView;
	NSLayoutConstraint *_messageThreadViewTopContraint;
	NSMutableArray *_messageEditorWindowControllers;
    NSMutableArray *_messageWindowControllers;
    Boolean _operationQueueShown;
    Boolean _inboxNotInitializedYet;
}

- (void)awakeFromNib {
	SM_LOG_DEBUG(@"SMAppController: awakeFromNib: _messageListViewController %@", _messageListViewController);
	
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	appDelegate.appController = self;

	//
	
	_messageThreadAndFindContentsPanelView = [[NSView alloc] init];
	_messageThreadAndFindContentsPanelView.translatesAutoresizingMaskIntoConstraints = NO;
	
	//

	_folderColorController = [[SMFolderColorController alloc] init];

	//

	_instrumentPanelViewController = [ [ SMInstrumentPanelViewController alloc ] initWithNibName:@"SMInstrumentPanelViewController" bundle:nil ];
	
	NSAssert(_instrumentPanelViewController, @"_instrumentPanelViewController");
	
	NSView *instrumentPanelView = [ _instrumentPanelViewController view ];
	
	NSAssert(instrumentPanelView, @"instrumentPanelView");
	
	//

	_mailboxViewController = [ [ SMMailboxViewController alloc ] initWithNibName:@"SMMailboxViewController" bundle:nil ];

	NSAssert(_mailboxViewController, @"_mailboxViewController");
	
	NSView *mailboxView = [ _mailboxViewController view ];

	NSAssert(mailboxView, @"mailboxView");

	//
	
	_searchResultsListViewController = [ [ SMSearchResultsListViewController alloc ] initWithNibName:nil bundle:nil ];
	
	NSAssert(_searchResultsListViewController, @"_searchResultsListViewController");
	
	NSView *searchResultsListView = [ _searchResultsListViewController view ];
	
	NSAssert(searchResultsListView, @"searchResultsListView");

	//

	_messageListViewController = [ [ SMMessageListViewController alloc ] initWithNibName:@"SMMessageListViewController" bundle:nil ];
	
	NSAssert(_messageListViewController, @"_messageListViewController");
		
	NSView *messageListView = [ _messageListViewController view ];

	NSAssert(messageListView, @"messageListView");
	
	//
	
	_messageThreadViewController = [ [ SMMessageThreadViewController alloc ] initWithNibName:nil bundle:nil ];
	
	NSAssert(_messageThreadViewController, @"_messageThreadViewController");
	
	NSView *messageThreadView = [ _messageThreadViewController view ];
	
	NSAssert(messageThreadView, @"messageThreadView");

	[messageThreadView setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];

	[_messageThreadAndFindContentsPanelView addSubview:messageThreadView];
	
	[_messageThreadAndFindContentsPanelView addConstraint:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:messageThreadView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[_messageThreadAndFindContentsPanelView addConstraint:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:messageThreadView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
	
	[_messageThreadAndFindContentsPanelView addConstraint:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:messageThreadView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];

	_messageThreadViewTopContraint = [NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:messageThreadView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
	
	[_messageThreadAndFindContentsPanelView addConstraint:_messageThreadViewTopContraint];
	
	//
	
	NSSplitView *mailboxAndSearchResultsView = [[NSSplitView alloc] init];
	mailboxAndSearchResultsView.translatesAutoresizingMaskIntoConstraints = NO;
	
	[mailboxAndSearchResultsView setDelegate:self];
	
	[mailboxAndSearchResultsView setVertical:NO];
	[mailboxAndSearchResultsView setDividerStyle:NSSplitViewDividerStyleThin];
	
	[mailboxAndSearchResultsView addSubview:mailboxView];
	[mailboxAndSearchResultsView addSubview:searchResultsListView];
	
	[mailboxAndSearchResultsView adjustSubviews];
	
	//
	
	[_instrumentPanelViewController.workView addSubview:mailboxAndSearchResultsView];

	[_instrumentPanelViewController.workView addConstraint:
	 [NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView
								  attribute:NSLayoutAttributeLeading
								  relatedBy:NSLayoutRelationEqual
									 toItem:mailboxAndSearchResultsView
								  attribute:NSLayoutAttributeLeading
								 multiplier:1
								   constant:0]];

	[_instrumentPanelViewController.workView addConstraint:
	 [NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView
								  attribute:NSLayoutAttributeTrailing
								  relatedBy:NSLayoutRelationEqual
									 toItem:mailboxAndSearchResultsView
								  attribute:NSLayoutAttributeTrailing
								 multiplier:1
								   constant:0]];
	
	[_instrumentPanelViewController.workView addConstraint:
	 [NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView
								  attribute:NSLayoutAttributeTop
								  relatedBy:NSLayoutRelationEqual
									 toItem:mailboxAndSearchResultsView
								  attribute:NSLayoutAttributeTop
								 multiplier:1
								   constant:0]];
	
	[_instrumentPanelViewController.workView addConstraint:
	 [NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView
								  attribute:NSLayoutAttributeBottom
								  relatedBy:NSLayoutRelationEqual
									 toItem:mailboxAndSearchResultsView
								  attribute:NSLayoutAttributeBottom
								 multiplier:1
								   constant:0]];
	
	//
	
	NSSplitView *splitView = [[NSSplitView alloc] init];
	splitView.translatesAutoresizingMaskIntoConstraints = NO;

	[splitView setVertical:YES];
	[splitView setDividerStyle:NSSplitViewDividerStyleThin];
	
	[splitView addSubview:instrumentPanelView];
	[splitView addSubview:messageListView];
	[splitView addSubview:_messageThreadAndFindContentsPanelView];
	
	[splitView adjustSubviews];

	[splitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-1 forSubviewAtIndex:0];
	[splitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-2 forSubviewAtIndex:1];
	[splitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-3 forSubviewAtIndex:2];

	[_view addSubview:splitView];
	
	// 

	[_view addConstraint:[NSLayoutConstraint constraintWithItem:mailboxView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:_view attribute:NSLayoutAttributeHeight multiplier:0.3 constant:0]];

	[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:splitView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
	
	[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:splitView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
	
	[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:splitView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];

	[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:splitView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
	
	//
	
	[self hideSearchResultsView];
	
	//
	
	_messageEditorWindowControllers = [NSMutableArray array];
    _messageWindowControllers = [NSMutableArray array];
	
	//
	
	_outboxController = [[SMOutboxController alloc] init];
    
    //
    
    _operationExecutor = [[SMOperationExecutor alloc] init];
}

- (void)updateMailboxFolderList {
	[ _mailboxViewController updateFolderListView ];

    if(!_inboxNotInitializedYet) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

        [[[appDelegate model] messageListController] changeFolder:@"INBOX"];
        [[[appDelegate appController] mailboxViewController] changeFolder:@"INBOX"];
        
        _inboxNotInitializedYet = YES;
    }
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = nil;
	
	if([itemIdent isEqual:SearchDocToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];

		[toolbarItem setLabel:@"Search"];
		[toolbarItem setPaletteLabel:@"Search"];
		[toolbarItem setToolTip:@"Search for messages"];
		
		_searchField = [[NSSearchField alloc] initWithFrame:[_searchField frame]];
		[_searchField.cell setSendsWholeSearchString:YES];

		[toolbarItem setView:_searchField];
		[toolbarItem setMinSize:NSMakeSize(30, NSHeight([_searchField frame]))];
		[toolbarItem setMaxSize:NSMakeSize(400,NSHeight([_searchField frame]))];
	} else if([itemIdent isEqual:ComposeMessageToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];
		
		[toolbarItem setPaletteLabel:@"New message"];
		[toolbarItem setToolTip: @"Compose new message"];
		
		_composeMessageButton = [[NSButton alloc] initWithFrame:[_composeMessageButton frame]];
		[_composeMessageButton setImage:[NSImage imageNamed:@"new-message.png"]];
		[_composeMessageButton.cell setImageScaling:NSImageScaleProportionallyDown];
		_composeMessageButton.bezelStyle = NSTexturedSquareBezelStyle;
		_composeMessageButton.target = self;
		_composeMessageButton.action = @selector(composeMessageAction:);
		
		[toolbarItem setView:_composeMessageButton];
	} else if([itemIdent isEqual:TrashToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];
		
		[toolbarItem setPaletteLabel:@"Trash"];
		[toolbarItem setToolTip: @"Put selected messages to trash"];

		_trashButton = [[NSButton alloc] initWithFrame:[_trashButton frame]];
		[_trashButton setImage:[NSImage imageNamed:@"trash-black.png"]];
		[_trashButton.cell setImageScaling:NSImageScaleProportionallyDown];
		_trashButton.bezelStyle = NSTexturedSquareBezelStyle;
		_trashButton.target = self;
		_trashButton.action = @selector(moveToTrashAction:);

		[toolbarItem setView:_trashButton];
	} else {
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa
		// Returning nil will inform the toolbar this kind of item is not supported
		toolbarItem = nil;
	}
	
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
	// Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default
	// If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
	// user chooses to revert to the default items this set will be used
	return [NSArray arrayWithObjects:ComposeMessageToolbarItemIdentifier, TrashToolbarItemIdentifier, SearchDocToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
	// Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar
	// does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed
	// The set of allowed items is used to construct the customization palette
	return [NSArray arrayWithObjects:ComposeMessageToolbarItemIdentifier, TrashToolbarItemIdentifier, SearchDocToolbarItemIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
	// Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
	// This is the best place to notice a new item is going into the toolbar.  For instance, if you need to
	// cache a reference to the toolbar item or need to set up some initial state, this is the best place
	// to do it.  The notification object is the toolbar to which the item is being added.  The item being
	// added is found by referencing the @"item" key in the userInfo
	NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];

	if([[addedItem itemIdentifier] isEqual:SearchDocToolbarItemIdentifier]) {
		[addedItem setTarget: self];
		[addedItem setAction: @selector(searchUsingToolbarSearchField:)];
		
		_activeSearchItem = addedItem;
	} else if([[addedItem itemIdentifier] isEqual:ComposeMessageToolbarItemIdentifier]) {
	} else if([[addedItem itemIdentifier] isEqual:TrashToolbarItemIdentifier]) {
//      TODO
//
//		[addedItem setTarget: self];
//		[addedItem setAction: @selector(:)];
//
//		_activeSearchItem = addedItem;
	}
}

- (void) searchUsingToolbarSearchField:(id) sender {
	// This message is sent when the user strikes return in the search field in the toolbar
	NSString *searchString = [(NSTextField *)[_activeSearchItem view] stringValue];

	if(searchString.length == 0)
		return;
	
	SM_LOG_DEBUG(@"searching for string '%@'", searchString);
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] searchResultsListController] startNewSearch:searchString exitingLocalFolder:nil];
	
	[self showSearchResultsView];
}

- (Boolean)isSearchResultsViewHidden {
	return _searchResultsShownConstraints != nil;
}

- (void)showSearchResultsView {
	if([self isSearchResultsViewHidden]) {
		[_searchResultsListViewController.view removeConstraints:[_searchResultsListViewController.view constraints]];
		[_searchResultsListViewController.view addConstraints:_searchResultsShownConstraints];
		
		_searchResultsShownConstraints = nil;
	}
}

- (void)hideSearchResultsView {
	if(![self isSearchResultsViewHidden]) {
		_searchResultsShownConstraints = [_searchResultsListViewController.view constraints];
		
		[_searchResultsListViewController.view removeConstraints:_searchResultsShownConstraints];
		[_searchResultsListViewController.view addConstraint:[NSLayoutConstraint constraintWithItem:_searchResultsListViewController.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1 constant:0]];
	}
}

- (void)toggleSearchResultsView {
	if([self isSearchResultsViewHidden]) {
		[self showSearchResultsView];
	} else {
		[self hideSearchResultsView];
	}
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	if([self isSearchResultsViewHidden])
		return NSZeroRect;
	
	return proposedEffectiveRect;
}

- (IBAction)moveToTrashAction:(id)sender {
    [self moveSelectedMessageThreadsToTrash];
}

- (void)moveSelectedMessageThreadsToTrash {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [[appDelegate model] mailbox];
    
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    [[[appDelegate appController] messageListViewController] moveSelectedMessageThreadsToFolder:trashFolder.fullName];
}

#pragma mark Find Contents panel management

- (IBAction)toggleFindContentsPanelAction:(id)sender {
	[self showFindContentsPanel];
}

- (void)showFindContentsPanel {
	if(_findContentsPanelShown)
		return;

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	if([[appDelegate appController] messageThreadViewController].currentMessageThread == nil)
		return;

	NSAssert(_messageThreadViewTopContraint != nil, @"_messageThreadViewTopContraint == nil");
	[_messageThreadAndFindContentsPanelView removeConstraint:_messageThreadViewTopContraint];
	
	if(_findContentsPanelViewController == nil) {
		_findContentsPanelViewController = [[SMFindContentsPanelViewController alloc] initWithNibName:@"SMFindContentsPanelViewController" bundle:nil];

		NSAssert(_findContentsPanelConstraints == nil, @"_findContentsPanelConstraints != nil");

		_findContentsPanelConstraints = [NSMutableArray array];

		[_findContentsPanelConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_findContentsPanelViewController.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
		
		[_findContentsPanelConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_findContentsPanelViewController.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
		
		[_findContentsPanelConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageThreadAndFindContentsPanelView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_findContentsPanelViewController.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
		
		[_findContentsPanelConstraints addObject:[NSLayoutConstraint constraintWithItem:_findContentsPanelViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_messageThreadViewController.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
	}

	[_messageThreadAndFindContentsPanelView addSubview:_findContentsPanelViewController.view];

	NSAssert(_findContentsPanelConstraints != nil, @"_findContentsPanelConstraints == nil");
	[_messageThreadAndFindContentsPanelView addConstraints:_findContentsPanelConstraints];

	NSSearchField *searchField = _findContentsPanelViewController.searchField;
	NSAssert(searchField != nil, @"searchField == nil");

	[[searchField window] makeFirstResponder:searchField];

	_findContentsPanelShown = YES;
}

- (void)hideFindContentsPanel {
	if(!_findContentsPanelShown)
		return;
	
	NSAssert(_findContentsPanelViewController != nil, @"_findContentsPanelViewController == nil");
	NSAssert(_findContentsPanelConstraints != nil, @"_findContentsPanelConstraints == nil");
	
	[_messageThreadAndFindContentsPanelView removeConstraints:_findContentsPanelConstraints];
	
	[_findContentsPanelViewController.view removeFromSuperview];
	[_messageThreadAndFindContentsPanelView addConstraint:_messageThreadViewTopContraint];

	[_messageThreadViewController removeFindContentsResults];

	_findContentsPanelShown = NO;
}

#pragma mark New label creation

- (void)showNewLabelSheet:(NSString*)suggestedParentFolder {
	if(_addNewLabelWindowController == nil)
		_addNewLabelWindowController = [[SMNewLabelWindowController alloc] initWithWindowNibName:@"SMNewLabelWindowController"];

	[_addNewLabelWindowController updateExistingLabelsList];	
	[_addNewLabelWindowController setSuggestedNestingLabel:suggestedParentFolder];

	NSWindow *newLabelSheet = _addNewLabelWindowController.window;
	NSAssert(newLabelSheet != nil, @"newLabelSheet is nil");

	[NSApp runModalForWindow:newLabelSheet];
}

- (void)hideNewLabelSheet {
	NSAssert(_addNewLabelWindowController != nil, @"_addNewLabelWindowController is nil");

	NSWindow *newLabelSheet = _addNewLabelWindowController.window;
	NSAssert(newLabelSheet != nil, @"newLabelSheet is nil");
	
	[newLabelSheet orderOut:self];

	[NSApp endSheet:newLabelSheet];
}


#pragma mark Operation Queue Window

- (void)toggleOperationQueueSheet {
    if(!_operationQueueShown) {
        [self showOperationQueueSheet];
    }
    else {
        [self hideOperationQueueSheet];
    }
}

- (void)showOperationQueueSheet {
    if(_operationQueueWindowController == nil) {
        _operationQueueWindowController = [[SMOperationQueueWindowController alloc] initWithWindowNibName:@"SMOperationQueueWindowController"];
    }
    
    [_operationQueueWindowController showWindow:self];

    _operationQueueShown = YES;
}

- (void)hideOperationQueueSheet {
    NSAssert(_operationQueueWindowController != nil, @"_addNewLabelWindowController is nil");
    
    NSWindow *sheet = _operationQueueWindowController.window;
    NSAssert(sheet != nil, @"sheet is nil");
    
    [sheet orderOut:self];
    
    [NSApp endSheet:sheet];

    _operationQueueShown = NO;
}

#pragma mark Message editor window management

- (IBAction)composeMessageAction:(id)sender {
    [self openMessageEditorWindow:nil subject:nil to:nil cc:nil bcc:nil draftUid:0];
}

- (void)openMessageEditorWindow:(NSString*)htmlContents subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid {
    SMMessageEditorWindowController *messageEditorWindowController = [[SMMessageEditorWindowController alloc] initWithWindowNibName:@"SMMessageEditorWindowController"];

    [messageEditorWindowController initHtmlContents:htmlContents subject:subject to:to cc:cc bcc:bcc draftUid:draftUid];
    [messageEditorWindowController showWindow:self];
    
    [_messageEditorWindowControllers addObject:messageEditorWindowController];
}

#pragma mark Message viewer window

- (void)openMessageWindow:(SMMessageThread*)messageThread {
    SMMessageWindowController *messageWindowController = [[SMMessageWindowController alloc] initWithWindowNibName:@"SMMessageWindowController"];
    
    [messageWindowController setCurrentMessageThread:messageThread];
    [messageWindowController showWindow:self];
    
    [_messageWindowControllers addObject:messageWindowController];
}

@end
