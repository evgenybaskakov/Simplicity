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
#import "SMUserAccount.h"
#import "SMStringUtils.h"
#import "SMDatabase.h"
#import "SMNotificationsController.h"
#import "SMMessageEditorWindowController.h"
#import "SMNewLabelWindowController.h"
#import "SMAccountsViewController.h"
#import "SMMailboxViewController.h"
#import "SMSearchLocalFolder.h"
#import "SMAccountSearchController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMInstrumentPanelViewController.h"
#import "SMFindContentsPanelViewController.h"
#import "SMOperationQueueWindowController.h"
#import "SMLocalFolderRegistry.h"
#import "SMFolderColorController.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMOutboxController.h"
#import "SMFolder.h"
#import "SMAbstractLocalFolder.h"
#import "SMUnifiedLocalFolder.h"
#import "SMLocalFolder.h"
#import "SMMessageThread.h"
#import "SMNewAccountWindowController.h"
#import "SMMessageWindowController.h"
#import "SMPreferencesWindowController.h"
#import "SMSectionMenuViewController.h"
#import "SMTokenFieldViewController.h"
#import "SMSearchRequestInputController.h"

static NSString *SearchDocToolbarItemIdentifier = @"Search Item Identifier";
static NSString *ComposeMessageToolbarItemIdentifier = @"Compose Message Item Identifier";
static NSString *TrashToolbarItemIdentifier = @"Trash Item Identifier";
static NSString *NavigateMessagesToolbarItemIdentifier = @"Navigate Messages Item Identifier";

@implementation SMAppController {
    NSButton *button1, *button2;
    NSToolbarItem *__weak _searchToolbarItem;
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
    Boolean _syncedFoldersInitialized;
    BOOL _preferencesWindowShown;
    BOOL _searchSuggestionsMenuShown;
    BOOL _searchingForSuggestions;
    BOOL _searchingForContent;
}

- (void)awakeFromNib {
    SM_LOG_DEBUG(@"SMAppController: awakeFromNib: _messageListViewController %@", _messageListViewController);
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    appDelegate.appController = self;

    //
    
    _textFormatMenuItem.enabled = NO;
    _htmlTextFormatMenuItem.enabled = NO;
    _plainTextFormatMenuItem.enabled = NO;
    
    //
    
    _messageThreadAndFindContentsPanelView = [[NSView alloc] init];
    _messageThreadAndFindContentsPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    
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
    
    _accountsViewController = [ [ SMAccountsViewController alloc ] initWithNibName:nil bundle:nil ];
    
    NSAssert(_accountsViewController, @"_accountsViewController");
    
    NSView *accountsView = [ _accountsViewController view ];
    
    NSAssert(accountsView, @"accountsView");
    
    accountsView.translatesAutoresizingMaskIntoConstraints = NO;
    
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
    
    [_instrumentPanelViewController.workView addSubview:accountsView];

    [_instrumentPanelViewController.workView addConstraint:[NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:accountsView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    [_instrumentPanelViewController.workView addConstraint:[NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:accountsView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    [_instrumentPanelViewController.workView addConstraint:[NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:accountsView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    
    [_instrumentPanelViewController.workView addConstraint:[NSLayoutConstraint constraintWithItem:_instrumentPanelViewController.workView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:accountsView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    //
    
    NSSplitView *mainSplitView = [[NSSplitView alloc] init];
    mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [mainSplitView setVertical:YES];
    [mainSplitView setDividerStyle:NSSplitViewDividerStyleThin];
    
    [mainSplitView addSubview:instrumentPanelView];
    [mainSplitView addSubview:messageListView];
    [mainSplitView addSubview:_messageThreadAndFindContentsPanelView];
    
    [mainSplitView adjustSubviews];

    [mainSplitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-1 forSubviewAtIndex:0];
    [mainSplitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-2 forSubviewAtIndex:1];
    [mainSplitView setHoldingPriority:NSLayoutPriorityDragThatCannotResizeWindow-3 forSubviewAtIndex:2];
    
    mainSplitView.autosaveName = @"MainSplitView";
    
    [_view addSubview:mainSplitView];
    
    //

    [_view addConstraint:[NSLayoutConstraint constraintWithItem:accountsView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:_view attribute:NSLayoutAttributeHeight multiplier:0.3 constant:0]];

    [_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:mainSplitView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    
    [_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:mainSplitView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
    
    [_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:mainSplitView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];

    [_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:mainSplitView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    
    //
    
    _messageEditorWindowControllers = [NSMutableArray array];
    _messageWindowControllers = [NSMutableArray array];
    
    //
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateMailboxFolderList:) name:@"FolderListUpdated" object:nil];
    
    //
    
    _searchRequestInputController = [[SMSearchRequestInputController alloc] init];
    
    //
    
    _searchMenuViewController = [[SMSectionMenuViewController alloc] initWithNibName:@"SMSectionMenuViewController" bundle:nil];
    
    //
    
    _searchSuggestionsMenu = [NSWindow windowWithContentViewController:_searchMenuViewController];
    _searchSuggestionsMenu.styleMask = NSBorderlessWindowMask;
    _searchSuggestionsMenu.level = NSFloatingWindowLevel;
    _searchSuggestionsMenu.delegate = self;
    _searchSuggestionsMenu.backgroundColor = [NSColor clearColor];
    
    //
    
    _searchFieldViewController = [[SMTokenFieldViewController alloc] initWithNibName:@"SMTokenFieldViewController" bundle:nil];
    NSAssert(_searchFieldViewController.view != nil, @"_searchFieldViewController is nil");

    _searchField = _searchFieldViewController.view;
    [_searchToolbarItem setView:_searchField];

    _searchFieldViewController.target = self;
    _searchFieldViewController.action = @selector(searchUsingToolbarSearchField:);
    _searchFieldViewController.actionDelay = 0.2;
    _searchFieldViewController.cancelAction = @selector(cancelSearchUsingToolbarSearchField:);
    _searchFieldViewController.clearAction = @selector(clearSearchUsingToolbarSearchField:);
    _searchFieldViewController.enterAction = @selector(enterSearchUsingToolbarSearchField:);
    _searchFieldViewController.arrowUpAction = @selector(searchMenuCursorUp:);
    _searchFieldViewController.arrowDownAction = @selector(searchMenuCursorDown:);
    
    //
    
    SMMailboxTheme mailboxTheme = [[appDelegate preferencesController] mailboxTheme];

    [_accountsViewController setMailboxTheme:mailboxTheme];

    //
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsUpdated:) name:@"MessageFlagsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
}

- (void)messageHeadersSyncFinished:(NSNotification*)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder hasUpdates:nil account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) { // TODO: do we need this check?
        [self updateApplicationUnreadCountBadge:localFolder];
    }
}

- (void)messageFlagsUpdated:(NSNotification*)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageFlagsUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) { // TODO: do we need this check?
        [self updateApplicationUnreadCountBadge:localFolder];
    }
}

- (void)messagesUpdated:(NSNotification*)notification {
    SMLocalFolder *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessagesUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) { // TODO: do we need this check?
        [self updateApplicationUnreadCountBadge:localFolder];
    }

    if(localFolder.syncedWithRemoteFolder) {
        [account.database updateDBFolder:localFolder.remoteFolderName unreadCount:localFolder.unseenMessagesCount];
    }
}

- (void)updateMailboxFolderListForAccount:(id<SMAbstractAccount>)account {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SM_LOG_DEBUG(@"Updating folder list...");

    if(account == appDelegate.currentAccount) {
        [ _mailboxViewController updateFolderListView ];
    }
    
    if(!account.foldersInitialized) {
        SMFolder *inboxFolder = [[account mailbox] inboxFolder];
        if(inboxFolder != nil) {
            [[account messageListController] changeFolder:inboxFolder.fullName clearSearch:YES];
            [[account mailboxController] changeFolder:inboxFolder];
            
            if(appDelegate.currentAccountIsUnified || account == appDelegate.currentAccount) {
                [[[appDelegate appController] mailboxViewController] updateFolderListView];
            }
            
            account.foldersInitialized = YES;
        }
        else {
            SM_LOG_DEBUG(@"Folders not loaded yet");
        }
    }
}

- (void)updateMailboxFolderList:(NSNotification*)notification {
    SMUserAccount *account;
    [SMNotificationsController getFolderListUpdatedParams:notification account:&account];
    
    [self updateMailboxFolderListForAccount:account];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdent isEqual:SearchDocToolbarItemIdentifier]) {
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];

        [toolbarItem setLabel:@"Search"];
        [toolbarItem setPaletteLabel:@"Search"];
        [toolbarItem setToolTip:@"Search for messages"];
        [toolbarItem setView:_searchField];
        [toolbarItem setMinSize:NSMakeSize(200, NSHeight([_searchField frame]))];
        [toolbarItem setMaxSize:NSMakeSize(400, NSHeight([_searchField frame]))];
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
    } else if([itemIdent isEqual:NavigateMessagesToolbarItemIdentifier]) {
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];
        
        [toolbarItem setPaletteLabel:@"Navigate messages in current conversation"];
        [toolbarItem setToolTip: @"Navigate messages"];
        
        _messageNavigationControl = [[NSSegmentedControl alloc] initWithFrame:[_messageNavigationControl frame]];
        _messageNavigationControl.target = self;
        _messageNavigationControl.action = @selector(messageNavigationAction:);
        _messageNavigationControl.segmentStyle = NSSegmentStyleTexturedRounded;
        _messageNavigationControl.trackingMode = NSSegmentSwitchTrackingMomentary;
        _messageNavigationControl.segmentCount = 4;
        
        [_messageNavigationControl setWidth:26 forSegment:0];
        [_messageNavigationControl setImage:[NSImage imageNamed:@"Button-Up-128.png"]  forSegment:0];
        [_messageNavigationControl setImageScaling:NSImageScaleProportionallyDown forSegment:0];
         
        [_messageNavigationControl setWidth:26 forSegment:1];
        [_messageNavigationControl setImage:[NSImage imageNamed:@"Button-Down-128.png"] forSegment:1];
        [_messageNavigationControl setImageScaling:NSImageScaleProportionallyDown forSegment:1];

        [_messageNavigationControl setWidth:26 forSegment:2];
        [_messageNavigationControl setImage:[NSImage imageNamed:@"Button-Collapse.png"] forSegment:2];
        [_messageNavigationControl setImageScaling:NSImageScaleProportionallyDown forSegment:2];
        
        [_messageNavigationControl setWidth:26 forSegment:3];
        [_messageNavigationControl setImage:[NSImage imageNamed:@"Button-Expand.png"] forSegment:3];
        [_messageNavigationControl setImageScaling:NSImageScaleProportionallyDown forSegment:3];
        
        [toolbarItem setView:_messageNavigationControl];
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
    return [NSArray arrayWithObjects:ComposeMessageToolbarItemIdentifier, TrashToolbarItemIdentifier, NavigateMessagesToolbarItemIdentifier, SearchDocToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed
    // The set of allowed items is used to construct the customization palette
    return [NSArray arrayWithObjects:ComposeMessageToolbarItemIdentifier, TrashToolbarItemIdentifier, NavigateMessagesToolbarItemIdentifier, SearchDocToolbarItemIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being
    // added is found by referencing the @"item" key in the userInfo
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];

    if([[addedItem itemIdentifier] isEqual:SearchDocToolbarItemIdentifier]) {
        _searchToolbarItem = addedItem;
    } else if([[addedItem itemIdentifier] isEqual:ComposeMessageToolbarItemIdentifier]) {
    } else if([[addedItem itemIdentifier] isEqual:TrashToolbarItemIdentifier]) {
//      TODO
    }
}

- (void)clearSearch:(BOOL)changeToPrevFolder cancelFocus:(BOOL)cancelFocus {
    [_searchFieldViewController deleteAllTokensAndText];
    [_searchFieldViewController stopProgress];
    
    _searchingForSuggestions = NO;
    _searchingForContent = NO;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    [[appDelegate.currentAccount searchController] stopLatestSearch];
    
    if(changeToPrevFolder) {
        // If the current account is unified, it means the search results
        // is loaded within each. So clear evething.
        // TODO: get rid of this weird logic (See issue #103).
        if(appDelegate.currentAccountIsUnified) {
            for(id<SMAbstractAccount> account in appDelegate.accounts) {
                [[account messageListController] changeToPrevFolder];
            }
        }

        [[appDelegate.currentAccount messageListController] changeToPrevFolder];
        [[[appDelegate appController] mailboxViewController] changeToPrevFolder];
    }
    
    if(cancelFocus) {
        NSView *messageListView = [[[appDelegate appController] messageListViewController] view];
        [[_searchField window] makeFirstResponder:messageListView];
    }
}

- (void)finishSearch:(SMSearchOperationKind)searchOperationKind {
    switch(searchOperationKind) {
        case SMSearchOperationKind_Suggestions:
            _searchingForSuggestions = NO;
            break;

        case SMSearchOperationKind_Content:
            _searchingForContent = NO;
            break;
            
        default:
            SM_FATAL(@"Unknown search operation kind %lu", searchOperationKind);
    }

    if(!_searchingForSuggestions && !_searchingForContent) {
        [_searchFieldViewController stopProgress];
    }
}

- (void)searchUsingToolbarSearchField:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] mailboxViewController] clearSelection];
    
    [self startNewSearch:YES];
}

- (void)cancelSearchUsingToolbarSearchField:(id)sender {
    if(_searchSuggestionsMenuShown) {
        [self closeSearchSuggestionsMenu];
    }
    else {
        [self clearSearch:YES cancelFocus:YES];
    }
}

- (void)clearSearchUsingToolbarSearchField:(id)sender {
    [self closeSearchSuggestionsMenu];
    [self clearSearch:YES cancelFocus:YES];
}

- (void)enterSearchUsingToolbarSearchField:(id)sender {
    if(_searchSuggestionsMenuShown && [_searchMenuViewController triggerSelectedItemAction]) {
        [self closeSearchSuggestionsMenu];
    }
    else {
        [self closeSearchSuggestionsMenu];
        [self startNewSearch:NO];
    }
}

- (void)searchMenuCursorUp:(id)sender {
    [_searchMenuViewController cursorUp];
}

- (void)searchMenuCursorDown:(id)sender {
    [_searchMenuViewController cursorDown];
}

- (void)closeSearchMenu:(BOOL)force {
    if(_searchSuggestionsMenuShown || force) {
        [_searchSuggestionsMenu orderOut:self];
        
        _searchSuggestionsMenuShown = NO;
    }
}

- (void)closeSearchSuggestionsMenu {
    [self closeSearchMenu:NO];
}

- (void)adjustSearchSuggestionsMenuFrame {
    CGFloat menuHeight = _searchMenuViewController.totalHeight;
    menuHeight = MIN(menuHeight, 400);
    
    NSWindow *mainWindow = [[NSApplication sharedApplication] mainWindow];

    NSPoint pos = [_searchField.superview convertPoint:_searchField.frame.origin toView:nil];
    [_searchSuggestionsMenu setFrame:CGRectMake(mainWindow.frame.origin.x + pos.x - (_searchSuggestionsMenu.frame.size.width - _searchField.frame.size.width)/2, mainWindow.frame.origin.y + pos.y - menuHeight - 3, _searchSuggestionsMenu.frame.size.width, menuHeight) display:YES];
}

- (void)windowDidResignMain:(NSNotification *)notification {
    [self closeSearchSuggestionsMenu];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [self closeSearchSuggestionsMenu];
}

- (Boolean)isSearchResultsViewHidden {
    return _searchResultsShownConstraints != nil;
}

- (void)startNewSearch:(BOOL)showSuggestionsMenu {
    NSString *searchString = [SMStringUtils trimString:_searchFieldViewController.stringValue];
    
    if(searchString.length == 0 && _searchFieldViewController.tokenCount == 0) {
        [self closeSearchSuggestionsMenu];
        [self clearSearch:YES cancelFocus:NO];
        return;
    }
    
    _searchSuggestionsMenuShown = NO;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[appDelegate.appController searchRequestInputController] startNewSearchWithPattern:searchString]) {
        [_searchFieldViewController startProgress];

        _searchingForSuggestions = YES;
        _searchingForContent = YES;

        if(showSuggestionsMenu && searchString.length != 0) {
            [_searchSuggestionsMenu makeKeyAndOrderFront:self];
            
            [self adjustSearchSuggestionsMenuFrame];
            
            _searchSuggestionsMenuShown = YES;
        }
    }
    else {
        [self closeSearchMenu:YES];
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
    
    SMFolder *trashFolder = [appDelegate.currentMailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    [[[appDelegate appController] messageListViewController] moveSelectedMessageThreadsToFolder:trashFolder];
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
    if(_addNewLabelWindowController == nil) {
        _addNewLabelWindowController = [[SMNewLabelWindowController alloc] initWithWindowNibName:@"SMNewLabelWindowController"];
    }

    _addNewLabelWindowController.suggestedNestingLabel = suggestedParentFolder;

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
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(appDelegate.accounts.count == 0) {
        SM_LOG_INFO(@"no accounts");
        return;
    }
    
    Boolean plainText = [appDelegate.preferencesController preferableMessageFormat] == SMPreferableMessageFormat_RawText? YES : NO;
    [self openMessageEditorWindow:nil plainText:plainText subject:nil to:nil cc:nil bcc:nil draftUid:0 mcoAttachments:nil];
}

- (void)openMessageEditorWindow:(NSString*)textContent plainText:(Boolean)plainText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments {
    SMMessageEditorWindowController *messageEditorWindowController = [[SMMessageEditorWindowController alloc] initWithWindowNibName:@"SMMessageEditorWindowController"];

    [messageEditorWindowController initHtmlContents:textContent plainText:plainText subject:subject to:to cc:cc bcc:bcc draftUid:draftUid mcoAttachments:mcoAttachments];
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

#pragma mark Menu actions

- (IBAction)showNewAccountWindowAction:(id)sender {
    [self showNewAccountWindow];
}

- (void)showNewAccountWindow {
    if(_createNewAccountWindowController == nil) {
        _createNewAccountWindowController = [[SMNewAccountWindowController alloc] initWithWindowNibName:@"SMNewAccountWindowController"];
    }
    else {
        [_createNewAccountWindowController resetState];
    }
    
    NSWindow *newAccountSheet = _createNewAccountWindowController.window;
    NSAssert(newAccountSheet != nil, @"newAccountSheet is nil");
    
    [NSApp runModalForWindow:newAccountSheet];
}

- (void)closeNewAccountWindow {
    NSAssert(_createNewAccountWindowController != nil, @"_createNewAccountWindowController is nil");
    
    NSWindow *newAccountSheet = _createNewAccountWindowController.window;
    NSAssert(newAccountSheet != nil, @"newAccountSheet is nil");
    
    [newAccountSheet orderOut:self];
    
    [NSApp endSheet:newAccountSheet];
}

- (IBAction)showPreferencesWindowAction:(id)sender {
    _preferencesWindowShown = YES;
    
    if(_preferencesWindowController == nil) {
        _preferencesWindowController = [[SMPreferencesWindowController alloc] initWithWindowNibName:@"SMPreferencesWindowController"];
    }
    
    NSWindow *preferencesSheet = _preferencesWindowController.window;
    NSAssert(preferencesSheet != nil, @"preferencesSheet is nil");
    
    [NSApp runModalForWindow:preferencesSheet];
}

- (BOOL)preferencesWindowShown {
    return _preferencesWindowShown;
}

- (void)hidePreferencesWindow {
    NSAssert(_preferencesWindowController != nil, @"_preferencesWindowController is nil");
    
    NSWindow *preferencesSheet = _preferencesWindowController.window;
    NSAssert(preferencesSheet != nil, @"preferencesSheet is nil");
    
    [preferencesSheet orderOut:self];
    
    [NSApp endSheet:preferencesSheet];
    
    _preferencesWindowShown = NO;
}

#pragma mark Folder stats

- (void)updateApplicationUnreadCountBadge:(SMLocalFolder*)localFolder {
/*
 
 TODO!
 
 
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *inboxFolder = [appDelegate.currentMailbox inboxFolder];
    id<SMAbstractLocalFolder> inboxLocalFolder = [[appDelegate.currentAccount localFolderRegistry] getLocalFolderByName:inboxFolder.fullName];
    
    // TODO: use sum for inbox folders across all accounts

    if(((appDelegate.currentAccountIsUnified && [(SMUnifiedLocalFolder*)inboxLocalFolder attachedLocalFolderForAccount:\
                                                 appDelegate.currentAccount] == localFolder) || ((SMLocalFolder*)inboxLocalFolder == localFolder))) {
        NSString *messageCountString;
        
        if(inboxLocalFolder.unseenMessagesCount > 999) {
            messageCountString = @"999+";
        }
        else if(inboxLocalFolder.unseenMessagesCount > 0) {
            messageCountString = [NSString stringWithFormat:@"%lu", inboxLocalFolder.unseenMessagesCount];
        }
        else {
            messageCountString = @"";
        }
        
        [[[NSApplication sharedApplication] dockTile] setBadgeLabel:messageCountString];
    }
 */
}

#pragma mark Navigation in message thread

- (void)messageNavigationAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    switch(_messageNavigationControl.selectedSegment) {
    case 0:
        [[[appDelegate appController] messageThreadViewController] scrollToPrevMessage];
        break;
    case 1:
        [[[appDelegate appController] messageThreadViewController] scrollToNextMessage];
        break;
    case 2:
        [[[appDelegate appController] messageThreadViewController] collapseAll];
        break;
    case 3:
        [[[appDelegate appController] messageThreadViewController] uncollapseAll];
        break;
    }
}

@end
