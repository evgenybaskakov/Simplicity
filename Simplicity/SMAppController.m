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

@implementation SMAppController {
    NSButton *button1, *button2;
    NSLayoutConstraint *_searchResultsHeightConstraint;
    NSArray *_searchResultsShownConstraints;
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
    [mainSplitView addSubview:messageThreadView];
    
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

    [_searchFieldToolbarItem setView:_searchFieldViewController.view];

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
    
    _messageNavigationControl.enabled = NO;
    
    //
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsUpdated:) name:@"MessageFlagsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncError:) name:@"AccountSyncError" object:nil];
}

- (void)accountSyncError:(NSNotification*)notification {
    NSError *error;
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncErrorParams:notification error:&error account:&account];
    
    NSAssert(account != nil, @"account is nil");
    NSAssert(error != nil, @"error is nil");
    
    BOOL showError;
    switch(error.code) {
        case MCOErrorTLSNotAvailable:
        case MCOErrorParse:
        case MCOErrorCertificate:
        case MCOErrorAuthentication:
        case MCOErrorGmailIMAPNotEnabled:
        case MCOErrorGmailExceededBandwidthLimit:
        case MCOErrorGmailTooManySimultaneousConnections:
        case MCOErrorMobileMeMoved:
        case MCOErrorYahooUnavailable:
        case MCOErrorStartTLSNotAvailable:
        case MCOErrorNeedsConnectToWebmail:
        case MCOErrorAuthenticationRequired:
        case MCOErrorInvalidAccount:
        case MCOErrorCompression:
        case MCOErrorGmailApplicationSpecificPasswordRequired:
        case MCOErrorServerDate:
        case MCOErrorNoValidServerFound:
            showError = YES;
            break;
            
        default:
            showError = NO;
            break;
    }
    
    if(showError) {
        NSString *errorDesc = [SMStringUtils trimString:error.localizedDescription];
        if(errorDesc.length == 0) {
            errorDesc = @"Unknown server error occurred.";
        }
        else if([errorDesc characterAtIndex:errorDesc.length-1] != '.') {
            errorDesc = [errorDesc stringByAppendingString:@"."];
        }
        
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Dismiss"];
        [alert addButtonWithTitle:@"Properties"];
        [alert setMessageText:[NSString stringWithFormat:@"There was a problem accessing your accout \"%@\"", account.accountName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ Error code %ld. Please choose either to open account preferences, or dismiss this message.", errorDesc, error.code]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if([alert runModal] == NSAlertSecondButtonReturn) {
            // Exit the alert modal loop first.
            // Easiest way is to dispatch the request to the main thread queue.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showPreferencesWindowAction:YES accountName:account.accountName];
            });
        }
    }
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
        [[_searchFieldViewController.view window] makeFirstResponder:messageListView];
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
    NSView *searchFieldView = _searchFieldViewController.view;

    NSPoint pos = [searchFieldView.superview convertPoint:searchFieldView.frame.origin toView:nil];
    [_searchSuggestionsMenu setFrame:CGRectMake(mainWindow.frame.origin.x + pos.x - (_searchSuggestionsMenu.frame.size.width - searchFieldView.frame.size.width)/2, mainWindow.frame.origin.y + pos.y - menuHeight - 3, _searchSuggestionsMenu.frame.size.width, menuHeight) display:YES];
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

- (IBAction)toggleFindContentsPanelAction:(id)sender {
    NSWindow *curWindow = [[NSApplication sharedApplication] keyWindow];
    
    if([curWindow.delegate isKindOfClass:[SMMessageWindowController class]]) {
        [[(SMMessageWindowController*)curWindow.delegate messageThreadViewController] showFindContentsPanel];
    }
    else if(curWindow == [[NSApplication sharedApplication] mainWindow]) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[appDelegate.appController messageThreadViewController] showFindContentsPanel];
    }
}

- (IBAction)toggleSearchMailboxPanelAction:(id)sender {
    [[self.view window] makeFirstResponder:_searchFieldViewController];
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

- (void)openMessageWindow:(SMMessageThread*)messageThread localFolder:(id<SMAbstractLocalFolder>)localFolder {
    SMMessageWindowController *messageWindowController = [[SMMessageWindowController alloc] initWithWindowNibName:@"SMMessageWindowController"];
    
    messageWindowController.messageThread = messageThread;
    messageWindowController.localFolder = localFolder;

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

- (void)showPreferencesWindowAction:(BOOL)showAccount accountName:(NSString*)accountName {
    _preferencesWindowShown = YES;
    
    if(_preferencesWindowController == nil) {
        _preferencesWindowController = [[SMPreferencesWindowController alloc] initWithWindowNibName:@"SMPreferencesWindowController"];
    }
    
    NSWindow *preferencesSheet = _preferencesWindowController.window;
    NSAssert(preferencesSheet != nil, @"preferencesSheet is nil");
    
    if(showAccount) {
        [_preferencesWindowController showAccount:accountName];
    }
    
    [NSApp runModalForWindow:preferencesSheet];
}

- (IBAction)showPreferencesWindowAction:(id)sender {
    [self showPreferencesWindowAction:NO accountName:nil];
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

- (IBAction)messageNavigationAction:(id)sender {
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

- (void)enableMessageThreadNavigationControl {
    _messageNavigationControl.enabled = YES;
}

- (void)disableMessageThreadNavigationControl {
    _messageNavigationControl.enabled = NO;
}

@end
