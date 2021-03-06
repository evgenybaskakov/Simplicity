//
//  SMMessageListViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMNotificationsController.h"
#import "SMImageRegistry.h"
#import "SMRoundedImageView.h"
#import "SMMessageThreadAccountProxy.h"
#import "SMMessageBodyViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageListCellView.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMFolderColorController.h"
#import "SMMessageBookmarksView.h"
#import "SMUserAccount.h"
#import "SMAbstractLocalFolder.h"
#import "SMUnifiedLocalFolder.h"
#import "SMLocalFolder.h"
#import "SMPreferencesController.h"
#import "SMAddressBookController.h"
#import "SMFolder.h"
#import "SMAddress.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageListRowView.h"
#import "SMMessageListToolbarViewController.h"

@interface ScrollPosition : NSObject

@property NSMutableArray<SMMessageThread*> *visibleMessageThreads;
@property NSMutableIndexSet *visibleSelectedMessageThreadIndexes;
@property CGFloat visibleRowOffset;
@property NSMutableDictionary *threadsAtRows;

@end

@implementation ScrollPosition

- (id)init {
    self = [super init];
    
    if(self) {
        _visibleMessageThreads = [NSMutableArray array];
        _visibleSelectedMessageThreadIndexes = [NSMutableIndexSet indexSet];
        _threadsAtRows = [NSMutableDictionary dictionary];
    }
    
    return self;
}

@end

@implementation SMMessageListViewController {
    SMMessageThread *_selectedMessageThread;
    SMMessageThread *_draggedMessageThread;
    NSMutableArray *_multipleSelectedMessageThreads;
    BOOL _immediateSelection;
    BOOL _mouseSelectionInProcess;
    BOOL _reloadDeferred;
    NSIndexSet *_selectedRowsWithMenu;
    NSMutableDictionary<NSString*, ScrollPosition*> *_folderScrollPositions;
    ScrollPosition *_currentFolderScrollPosition;
    BOOL _progressIndicatorShown;
    NSInteger _nextCellViewTag;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if(self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyFetched:) name:@"MessageBodyFetched" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountPreferencesChanged:) name:@"AccountPreferencesChanged" object:nil];
        
        _multipleSelectedMessageThreads = [NSMutableArray array];
        _folderScrollPositions = [NSMutableDictionary dictionary];
        _progressIndicatorShown = NO;
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [_messageListTableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [_messageListTableView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    [_messageListTableView setDoubleAction:@selector(openMessageInWindow:)];
    
    _messageListTableView.allowsColumnReordering = NO;
    
    _progressIndicator.hidden = YES;
}

- (void)showLoadProgress {
    if(_progressIndicatorShown) {
        return;
    }

    _progressIndicator.hidden = NO;
    _messageListTableView.hidden = YES;

    [_progressIndicator startAnimation:self];
    
    _progressIndicatorShown = YES;
}

- (void)hideLoadProgress {
    if(!_progressIndicatorShown) {
        return;
    }
    
    _progressIndicator.hidden = YES;
    _messageListTableView.hidden = NO;

    [_progressIndicator stopAnimation:self];
    
    _progressIndicatorShown = NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count == 0) {
        return 0;
    }
    
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    
    id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
    NSInteger messageThreadsCount = [currentFolder.messageStorage messageThreadsCount];

    SM_LOG_DEBUG(@"self %@, tableView %@, its datasource %@, view %@, messagesTableView %@, message threads count %ld", self, tableView, [tableView dataSource], [self view], _messageListTableView, messageThreadsCount);
    
    return messageThreadsCount;
}

- (void)changeSelectedMessageThread {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count == 0) {
        return;
    }

    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    NSUInteger selectedThreadsCount = (_selectedMessageThread != nil? 1 : _multipleSelectedMessageThreads.count);

    [[[appDelegate appController] messageThreadViewController] setMessageThread:_selectedMessageThread selectedThreadsCount:selectedThreadsCount localFolder:currentLocalFolder];
}

- (void)delayChangeSelectedMessageThread {
    [self performSelector:@selector(changeSelectedMessageThread) withObject:nil afterDelay:0.3];
}

- (void)cancelChangeSelectedMessageThread {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(changeSelectedMessageThread) object:nil];
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView {
    NSAssert(tableView == _messageListTableView, @"unknown tableView instance");
    
    NSIndexSet *selectedRows = [tableView selectedRowIndexes];
    NSUInteger selectedRow = [selectedRows firstIndex];
    
    // Force redraw for rows above disappearing ones as well.
    while(selectedRow != NSNotFound) {
        if(selectedRow > 0) {
            [[tableView rowViewAtRow:selectedRow-1 makeIfNecessary:NO] setNeedsDisplay:YES];
        }
        [[tableView rowViewAtRow:selectedRow makeIfNecessary:NO] setNeedsDisplay:YES];
        selectedRow = [selectedRows indexGreaterThanIndex:selectedRow];
    }
    
    return YES;
}

- (void)scrollToTop {
    if(_messageListTableView.numberOfRows != 0) {
        [_messageListTableView scrollRowToVisible:0];
    }
}

- (void)selectMessageThread:(SMMessageThread*)messageThread {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    NSAssert(currentLocalFolder != nil, @"bad corrent folder");
    
    NSUInteger messageThreadIdx = [currentLocalFolder.messageStorage getMessageThreadIndexByDate:messageThread];
    
    if(messageThreadIdx != NSNotFound) {
        _selectedMessageThread = messageThread;
    }
    else {
        _selectedMessageThread = nil;
    }
    
    [self changeSelectedMessageThread];
    
    [_messageListTableView scrollRowToVisible:messageThreadIdx];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self cancelChangeSelectedMessageThread];

    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];

    if(selectedRows.count <= 1) {
        [_multipleSelectedMessageThreads removeAllObjects];

        NSInteger selectedRow = [_messageListTableView selectedRow];
        
        if(selectedRow >= 0) {
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
            id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
            NSAssert(currentLocalFolder != nil, @"bad corrent folder");
            
            _selectedMessageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
            
            if(_selectedMessageThread != nil) {
                if(_immediateSelection) {
                    [self changeSelectedMessageThread];
                } else {
                    // delay the selection for a tiny bit to optimize fast cursor movements
                    // e.g. when the user uses up/down arrow keys to navigate, skipping many messages between selections
                    // cancel scheduled message list update coming from keyboard
                    [self delayChangeSelectedMessageThread];
                }
            } else {
                [_messageListTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
            }
        }
        
        _mouseSelectionInProcess = NO;
        _immediateSelection = NO;
        
        if(_reloadDeferred) {
            [self performSelector:@selector(reloadMessageList:) withObject:[NSNumber numberWithBool:YES] afterDelay:0];
            
            _reloadDeferred = NO;
        }
    } else {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
        id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
        NSAssert(currentLocalFolder != nil, @"bad corrent folder");
        
        // TODO: optimize later
        [_multipleSelectedMessageThreads removeAllObjects];

        NSUInteger selectedRow = [selectedRows firstIndex];
        while(selectedRow != NSNotFound) {
            SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
            if(messageThread != nil) {
                [_multipleSelectedMessageThreads addObject:messageThread];
                
                SM_LOG_DEBUG(@"row %lu, subject %@", selectedRow, [[[messageThread messagesSortedByDate] firstObject] subject]);
            } else {
                SM_LOG_DEBUG(@"selected thread at row %lu not found", selectedRow);
            }

            selectedRow = [selectedRows indexGreaterThanIndex:selectedRow];
        }

        _selectedMessageThread = nil;
        [self changeSelectedMessageThread];

        _mouseSelectionInProcess = NO;
        _immediateSelection = NO;
        _reloadDeferred = NO;
    }

    [self updateToolbarButtons];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SM_LOG_DEBUG(@"tableView %@, datasource %@, delegate call: %@, row %ld", tableView, [tableView dataSource], [tableColumn identifier], row);
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:row];

    if(messageThread == nil) {
        SM_LOG_DEBUG(@"row %ld, message thread is nil", row);
        return nil;
    }
    
    NSAssert([messageThread messagesCount], @"no messages in the thread");
    SMMessage *firstMessage = [messageThread messagesSortedByDate][0];
    
    SMMessageListCellView *view = [tableView makeViewWithIdentifier:@"MessageCell" owner:self];
    NSAssert(view != nil, @"view is nil");
    
    [view initFields];
    
    [view.fromTextField setStringValue:(firstMessage.fromAddress? firstMessage.fromAddress.stringRepresentationShort : @"")];
    [view.subjectTextField setStringValue:(firstMessage.subject? firstMessage.subject : @"")];
    [view.dateTextField setStringValue:firstMessage.localizedDate];

    if(currentLocalFolder.kind == SMFolderKindOutbox) {
        view.unseenButton.hidden = YES;
        view.starButton.hidden = YES;
    }
    else {
        view.unseenButton.hidden = NO;
        view.starButton.hidden = NO;
        
        if(messageThread.unseen) {
            [view.unseenButton setState:NSOnState];
        } else {
            [view.unseenButton setState:NSOffState];
        }

        if(messageThread.flagged) {
            [view.starButton setState:NSOnState];
        } else {
            [view.starButton setState:NSOffState];
        }
    }
    
    // the buttons within the table cells must know which row they're in
    // so their action will use this tag to reflect the button action to the
    // target message thread
    view.unseenButton.tag = row;
    view.starButton.tag = row;

    [self setToggleButtonAlpha:view.unseenButton];
    
    [view setMessagesCount:messageThread.messagesCount];
    
    SMFolder *currentFolder = [appDelegate.currentMailboxController selectedFolder];
    NSArray *bookmarkColors = [appDelegate.messageThreadAccountProxy colorsForMessageThread:messageThread folder:currentFolder labels:nil];
    [view.bookmarksView setBookmarkColors:bookmarkColors];

    if([[appDelegate preferencesController] shouldShowContactImages]) {
        [view showContactImage];
    }
    else {
        [view hideContactImage];
    }

    if(messageThread.hasAttachments) {
        [view showAttachmentImage];
    }
    else {
        [view hideAttachmentImage];
    }

    if(messageThread.hasDraft) {
        [view showDraftLabel];
    }
    else {
        [view hideDraftLabel];
    }
    
    NSString *bodyPreview = [firstMessage plainTextBody];
    if(bodyPreview == nil) {
        bodyPreview = @"";
    }
    else if(bodyPreview.length == 0) {
        bodyPreview = @"Message has no content.";
    }
        
    [view.messagePreviewTextField setStringValue:bodyPreview];
    
    view.tag = _nextCellViewTag++;
    
    if(firstMessage.fromAddress) {
        SMUserAccount *account = messageThread.account;
        if([account.accountAddress matchEmail:firstMessage.fromAddress]) {
            view.contactImage.image = account.accountImage;
        }
        else {
            BOOL allowWebSiteImage = [appDelegate.preferencesController shouldUseServerContactImages];
            NSImage *contactImage = [[appDelegate addressBookController] loadPictureForAddress:firstMessage.fromAddress searchNetwork:YES allowWebSiteImage:allowWebSiteImage tag:view.tag completionBlock:^(NSImage *image, NSInteger tag) {
                if(view.tag == tag) {
                    if(image != nil) {
                        view.contactImage.image = image;
                    }
                    else {
                        view.contactImage.image = [[appDelegate addressBookController] defaultUserImage];                
                    }
                }
            }];
            
            if(contactImage != nil) {
                view.contactImage.image = contactImage;
            }
            else {
                view.contactImage.image = [[appDelegate addressBookController] defaultUserImage];
            }
        }
    }
    else {
        view.contactImage.image = [[appDelegate addressBookController] defaultUserImage];
    }
    
    [_currentFolderScrollPosition.threadsAtRows setObject:messageThread forKey:[NSNumber numberWithUnsignedInteger:row]];
    
    return view;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    return [SMMessageListCellView heightForPreviewLines:[[appDelegate preferencesController] messageListPreviewLineCount]];
}

- (void)tableViewSelectionIsChanging:(NSNotification *)notification {
    SM_LOG_DEBUG(@"???");

    // cancel scheduled message list update coming from keyboard
    [self cancelChangeSelectedMessageThread];

    // for mouse events, react quickly
    _immediateSelection = YES;
    _mouseSelectionInProcess = YES;
}

- (void)reloadMessageListDelayed:(NSNumber*)preserveSelection {
    [self reloadMessageList:[preserveSelection boolValue]];
}

- (CGFloat)fullRowHeight {
    CGFloat rowHeight = [self tableView:_messageListTableView heightOfRow:0];
    
    return rowHeight + _messageListTableView.intercellSpacing.height;
}

- (void)saveScrollPosition {
    [_currentFolderScrollPosition.visibleMessageThreads removeAllObjects];
    [_currentFolderScrollPosition.visibleSelectedMessageThreadIndexes removeAllIndexes];

    NSRect visibleRect = _messageListTableView.visibleRect;
    
    if(visibleRect.origin.y <= 0) {
        return;
    }
    
    if(_currentFolderScrollPosition.threadsAtRows.count == 0) {
        return;
    }
    
    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];

    NSRange range = [_messageListTableView rowsInRect:visibleRect];
    for(NSUInteger row = range.location, i = 0; i < range.length; i++, row++) {
        SMMessageThread *messageThread = [_currentFolderScrollPosition.threadsAtRows objectForKey:[NSNumber numberWithUnsignedInteger:row]];
        
        if(messageThread != nil) {
            [_currentFolderScrollPosition.visibleMessageThreads addObject:messageThread];
            
            if([selectedRows containsIndex:row]) {
                [_currentFolderScrollPosition.visibleSelectedMessageThreadIndexes addIndex:i];
            }
         
            if(i == 0) {
                CGFloat rowHeight = [self fullRowHeight];
                _currentFolderScrollPosition.visibleRowOffset = fmodf(visibleRect.origin.y, rowHeight);
            }
        }
        else {
            SM_LOG_WARNING(@"Unexpectedly, no thread at row %lu", row);
        }
    }
}

- (void)restoreScrollPosition {
    if(_currentFolderScrollPosition == nil) {
        return;
    }
    
    // First try to jump to one of previously visible selected rows.
    for(NSUInteger i = _currentFolderScrollPosition.visibleSelectedMessageThreadIndexes.firstIndex; i != NSNotFound; i = [_currentFolderScrollPosition.visibleSelectedMessageThreadIndexes indexGreaterThanIndex:i]) {
        if([self restoreScrollPositionAtRowIndex:i]) {
            return;
        }
    }

    // If all selected rows vanished, try to jump to an old visible row.
    for(NSUInteger i = 0; i < _currentFolderScrollPosition.visibleMessageThreads.count; i++) {
        if([self restoreScrollPositionAtRowIndex:i]) {
            return;
        }
    }
}

- (BOOL)restoreScrollPositionAtRowIndex:(NSUInteger)idx {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    if(currentLocalFolder == nil) {
        return NO;
    }
    
    if(idx >= _currentFolderScrollPosition.visibleMessageThreads.count) {
        return NO;
    }
    
    SMMessageThread *messageThread = _currentFolderScrollPosition.visibleMessageThreads[idx];
    NSUInteger threadIndex = [currentLocalFolder.messageStorage getMessageThreadIndexByDate:messageThread];
    
    if(threadIndex != NSNotFound) {
        CGFloat rowHeight = [self fullRowHeight];
        CGFloat offset = threadIndex * rowHeight + _currentFolderScrollPosition.visibleRowOffset;
        if(offset > idx * rowHeight) {
            offset -= idx * rowHeight;
        }
        else {
            offset = 0;
        }
        
        NSPoint scrollPosition = NSMakePoint(0, offset);
        [_messageListTableView scrollPoint:scrollPosition];
        
        return YES;
    }
    
    return NO;
}

- (void)reloadMessageList:(BOOL)preserveSelection updateScrollPosition:(BOOL)updateScrollPosition {
    if(updateScrollPosition) {
        [self saveScrollPosition];
        [self reloadMessageList:preserveSelection];
        [self restoreScrollPosition];
    }
    else {
        [self reloadMessageList:preserveSelection];
    }
}

- (void)reloadMessageList:(BOOL)preserveSelection {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];

    if(currentLocalFolder.folderStillLoadingInitialState) {
        [[appDelegate.appController messageListViewController] showLoadProgress];
    }
    else {
        [[appDelegate.appController messageListViewController] hideLoadProgress];
    }

    // if there's a mouse selection is in process, we shouldn't reload the list
    // otherwise it would cancel the current mouse selection which
    // in turn would impact the user experience
    if(_mouseSelectionInProcess) {
        // mark this reload as deferred
        // so later, when the mouse selection is finally made,
        // the table will be explicitly reloaded
        _reloadDeferred = YES;
        return;
    }

    // this is an explicit request to reload the message list
    // therefore mark the selection change as immediate, so the user
    // will momentarily see the results
    _immediateSelection = YES;

    // now actually rebuild the message list table
    [_messageListTableView reloadData];

    // Reset the accumulated message thread positions collected from previous scrolling.
    // After reload data is done, they will be re-collected again.
    // Doing this prevents memory leak.
    [_currentFolderScrollPosition.threadsAtRows removeAllObjects];

    // Load the current folder scroll information.
    NSIndexSet *selectedThreads = [NSIndexSet indexSet];
    
    if(currentLocalFolder != nil) {
        _currentFolderScrollPosition = [_folderScrollPositions objectForKey:currentLocalFolder.localName];
        
        if(_currentFolderScrollPosition == nil) {
            _currentFolderScrollPosition = [[ScrollPosition alloc] init];
            [_folderScrollPositions setObject:_currentFolderScrollPosition forKey:currentLocalFolder.localName];
        }
        
        // after all is done, fix the currently selected
        // message cell, if needed
        if(preserveSelection) {
            id<SMAbstractMessageStorage> messageStorage = currentLocalFolder.messageStorage;
            
            if(_selectedMessageThread != nil) {
                NSAssert(_multipleSelectedMessageThreads.count == 0, @"multiple messages selection not empty");

                NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:_selectedMessageThread];
                
                if(threadIndex != NSNotFound) {
                    selectedThreads = [NSIndexSet indexSetWithIndex:threadIndex];
                }
            } else {
                NSMutableIndexSet *threadIndexes = [NSMutableIndexSet indexSet];
                
                for(SMMessageThread *t in _multipleSelectedMessageThreads) {
                    NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:t];
                    
                    if(threadIndex != NSNotFound)
                        [threadIndexes addIndex:threadIndex];
                }

                if(threadIndexes.count != 0) {
                    selectedThreads = threadIndexes;
                }
            }
        }
    }

    [_messageListTableView selectRowIndexes:selectedThreads byExtendingSelection:NO];

    if(selectedThreads.count == 0) {
        [_multipleSelectedMessageThreads removeAllObjects];
        _selectedMessageThread = nil;
    }

    [self updateToolbarButtons];
}

- (void)updateToolbarButtons {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListToolbarViewController *messageListToolbarViewController = [[appDelegate appController] messageListToolbarViewController];

    BOOL enable = _messageListTableView.selectedRowIndexes.count != 0? YES : NO;
    
    [[messageListToolbarViewController starButton] setEnabled:enable];
    [[messageListToolbarViewController replyButton] setEnabled:enable];
    [[messageListToolbarViewController trashButton] setEnabled:enable];
}

- (void)messageHeadersSyncFinished:(BOOL)hasUpdates updateScrollPosition:(BOOL)updateScrollPosition {
    if(hasUpdates) {
        [self reloadMessageList:YES updateScrollPosition:updateScrollPosition];
    }
}

- (void)messageBodyFetched:(NSNotification *)notification {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];

    if(currentLocalFolder == nil) {
        return;
    }

    SMLocalFolder *localFolder;
    uint64_t messageId;
    int64_t threadId;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchedParams:notification localFolder:&localFolder messageId:&messageId threadId:&threadId account:&account];
    
    if(appDelegate.currentAccountIsUnified || account == appDelegate.currentAccount) {
        SMMessageThread *messageThread = nil;

        if(appDelegate.currentAccountIsUnified) {
            NSAssert([(NSObject*)currentLocalFolder isKindOfClass:[SMUnifiedLocalFolder class]], @"current folder is not unified, the current account is");
            SMLocalFolder *attachedFolder = [(SMUnifiedLocalFolder*)currentLocalFolder attachedLocalFolderForAccount:account];
            
            if(attachedFolder == localFolder) {
                messageThread = [(SMMessageStorage*)attachedFolder.messageStorage messageThreadById:threadId];
            }
        }
        else if((SMLocalFolder*)currentLocalFolder == localFolder) {
            NSAssert([(NSObject*)currentLocalFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"current folder is unified, but it must not be");
            messageThread = [(SMMessageStorage*)currentLocalFolder.messageStorage messageThreadById:threadId];
        }

        if(messageThread != nil) {
            if([messageThread updateThreadAttributesForMessageId:messageId]) {
                NSUInteger threadIndex = [currentLocalFolder.messageStorage getMessageThreadIndexByDate:messageThread];
                
                if(threadIndex != NSNotFound) {
                    [_messageListTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:threadIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                }
            }
        }
    }
}

- (void)accountPreferencesChanged:(NSNotification*)notification {
    [self reloadMessageList:YES];
}

- (void)moveSelectedMessageThreadsToFolder:(SMFolder*)remoteFolder {
    SM_LOG_DEBUG(@"to remote folder %@", remoteFolder.fullName);
    
    // Action sequence:
    // - remote selected message threads from the list
    // - clear currently selected message
    // - start copy op
    // - once copy done, start 'add delete flag' op
    // - once flagging is done, start 'expunge folder' op
    // err-1. if copy op fails, retry N times, then revert the changes made to the message list
    // err-2. if flagging op fails, retry N times, then register the op and put it to background
    // err-3. if expunge op fails, retry N times, then register the op and put it to background

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];

    if(_selectedMessageThread == nil && _multipleSelectedMessageThreads.count == 0 && _draggedMessageThread == nil) {
        SM_LOG_DEBUG(@"no message threads selected for moving");
        return;
    }

    NSArray *messageThreadsToMove;

    if(_draggedMessageThread != nil) {
        messageThreadsToMove = @[_draggedMessageThread];
    }
    else if(_selectedMessageThread != nil) {
        messageThreadsToMove = @[_selectedMessageThread];
    }
    else {
        NSAssert(_multipleSelectedMessageThreads.count > 0, @"no message threads to drop");
        messageThreadsToMove = [NSArray arrayWithArray:_multipleSelectedMessageThreads];
    }
    
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    NSAssert(currentLocalFolder != nil, @"no current folder");

    NSMutableArray *messageThreadsCouldntBeMoved = [NSMutableArray array];

    for(SMMessageThread *messageThread in messageThreadsToMove) {
        if(![currentLocalFolder moveMessageThread:messageThread toRemoteFolder:remoteFolder.fullName]) {
            SM_LOG_WARNING(@"Could not move message thread %lld to %@", messageThread.threadId, remoteFolder.fullName);
            
            [messageThreadsCouldntBeMoved addObject:messageThread];
        }
    }

    if(_draggedMessageThread == nil) {
        _selectedMessageThread = nil;
        [_multipleSelectedMessageThreads removeAllObjects];
    }

    // Check how many threads could make the move
    // Use the rest to decide how to change the table selection
    if(messageThreadsCouldntBeMoved.count > 1) {
        [_multipleSelectedMessageThreads addObjectsFromArray:messageThreadsCouldntBeMoved];
    }
    else if(messageThreadsCouldntBeMoved.count == 1) {
        _selectedMessageThread = messageThreadsCouldntBeMoved[0];
    }
    else {
        NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];
        
        if(selectedRows.count > 0 && _draggedMessageThread == nil) {
            // Move the selection down after the message threads are deleted from the list.
            NSUInteger nextRow = selectedRows.firstIndex;
            _selectedMessageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:nextRow];
            
            // If there's no down, move the selection up.
            if(_selectedMessageThread == nil && nextRow > 0) {
                nextRow--;
                _selectedMessageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:nextRow];
            }

            if(_selectedMessageThread != nil) {
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:nextRow];
                [_messageListTableView selectRowIndexes:indexSet byExtendingSelection:NO];
            }
        }
    }

    [self changeSelectedMessageThread];

    _draggedMessageThread = nil;
    _mouseSelectionInProcess = NO;
    _immediateSelection = NO;
    _reloadDeferred = NO;

    BOOL preserveSelection = (_selectedMessageThread != nil || _multipleSelectedMessageThreads.count != 0? YES : NO);
    [self reloadMessageList:preserveSelection];
}

#pragma mark Messages drag and drop support

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
    if(aTableView == _messageListTableView) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
        [pboard setData:data forType:NSStringPboardType];

        if(rowIndexes.count == 1) {
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
            id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
            NSAssert(currentLocalFolder != nil, @"no current folder");

            SMMessageThread *drag = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:rowIndexes.firstIndex];
            
            if(drag == _selectedMessageThread || [_multipleSelectedMessageThreads containsObject:drag]) {
                // if the dragged thread is within the selection, use the general rules to perform the dragging
                drag = nil;
            }

            _draggedMessageThread = drag;
        }
        
        return YES;
    } else {
        return NO;
    }
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    // the message list view does not accept dropping

    return NSDragOperationNone;
}

- (void)setToggleButtonAlpha:(NSButton*)button {
    if(button.state == NSOnState) {
        [button setAlphaValue:1.0];
    } else {
        [button setAlphaValue:0.1];
    }
}

- (IBAction)toggleStarAction:(id)sender {
    NSButton *button = (NSButton*)sender;
    [self setToggleButtonAlpha:button];

    NSInteger row = button.tag;

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:row];
    
    NSAssert(messageThread != nil, @"row %ld, message thread is nil", row);
    NSAssert(messageThread.messagesCount > 0, @"row %ld, no messages in thread %llu", row, messageThread.threadId);
    
    if(messageThread.flagged) {
        [self removeStarFromMessageThread:messageThread];
    }
    else {
        [self addStarToMessageThread:messageThread];
    }
    
    [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
}

- (void)addStarToMessageThread:(SMMessageThread*)messageThread {
    //
    // TODO: Use not just the first message, but the first message that belongs to this remote folder
    //
    SMMessage *message = messageThread.messagesSortedByDate[0];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate.messageThreadAccountProxy setMessageFlagged:messageThread message:message flagged:YES];
    
    [messageThread updateThreadAttributesForMessageId:message.messageId];
}

- (void)removeStarFromMessageThread:(SMMessageThread*)messageThread {
    //
    // Gmail logic: remove the star from all messages in the thread.
    //
    for(SMMessage *message in messageThread.messagesSortedByDate) {
        //
        // TODO: Optimize by using the bulk API for setting IMAP flags
        //
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate.messageThreadAccountProxy setMessageFlagged:messageThread message:message flagged:NO];
        
        [messageThread updateThreadAttributesForMessageId:message.messageId];
    }
}

- (IBAction)toggleUnseenAction:(id)sender {
    NSButton *button = (NSButton*)sender;
    [self setToggleButtonAlpha:button];
    
    NSInteger row = button.tag;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:row];
    
    NSAssert(messageThread != nil, @"row %ld, message thread is nil", row);
    NSAssert(messageThread.messagesCount > 0, @"row %ld, no messages in thread %llu", row, messageThread.threadId);
    
    if(messageThread.unseen) {
        //
        // Gmail logic: make all messages in the thread to be seen.
        //
        for(SMMessage *message in messageThread.messagesSortedByDate) {
            //
            // TODO: Optimize by using the bulk API for setting IMAP flags
            //
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate.messageThreadAccountProxy setMessageUnseen:messageThread message:message unseen:NO];

            [messageThread updateThreadAttributesForMessageId:message.messageId];
        }
    }
    else {
        //
        // TODO: Use not just the first message, but the first message that belongs to this remote folder
        //
        SMMessage *message = messageThread.messagesSortedByDate[0];
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate.messageThreadAccountProxy setMessageUnseen:messageThread message:message unseen:!message.unseen];

        [messageThread updateThreadAttributesForMessageId:message.messageId];
    }
    
    [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
}

#pragma mark Context menu creation

- (NSMenu*)menuForRow:(NSInteger)row {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];

    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];
    if([selectedRows containsIndex:row]) {
        NSUInteger selectedRow = [selectedRows firstIndex];
        while(selectedRow != NSNotFound) {
            SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
            NSAssert(messageThread != nil, @"message thread at selected row %lu not found", selectedRow);
            
            selectedRow = [selectedRows indexGreaterThanIndex:selectedRow];
        }
        
        _selectedRowsWithMenu = selectedRows;
    }
    else {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
        [_messageListTableView selectRowIndexes:indexSet byExtendingSelection:NO];
        
        [self reloadMessageList:YES];
        
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:row];
        
        if(messageThread == nil) {
            SM_LOG_ERROR(@"clicked message thread at row %ld not found", row);
            // TODO: fix this logic
            return nil;
        }
        
        _selectedRowsWithMenu = indexSet;
    }

    BOOL onlyOneMessageThreadSelected = (_selectedRowsWithMenu.count == 1? YES : NO);
    
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    NSMenuItem *item = [menu addItemWithTitle:@"Reply" action:@selector(menuActionReply:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:onlyOneMessageThreadSelected];
    
    item = [menu addItemWithTitle:@"Reply All" action:@selector(menuActionReplyAll:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:onlyOneMessageThreadSelected];
    
    item = [menu addItemWithTitle:@"Forward" action:@selector(menuActionForward:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:onlyOneMessageThreadSelected];
    
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:@"Delete" action:@selector(menuActionDelete:) keyEquivalent:@""] setTarget:self];

    if(currentLocalFolder.kind != SMFolderKindOutbox) {
        [menu addItem:[NSMenuItem separatorItem]];
        
        [[menu addItemWithTitle:@"Mark as Read" action:@selector(menuActionMarkAsSeen:) keyEquivalent:@""] setTarget:self];
        [[menu addItemWithTitle:@"Mark as Unread" action:@selector(menuActionMarkAsUnseen:) keyEquivalent:@""] setTarget:self];
        [[menu addItemWithTitle:@"Add Star" action:@selector(menuActionAddStar:) keyEquivalent:@""] setTarget:self];
        [[menu addItemWithTitle:@"Remove Star" action:@selector(menuActionRemoveStar:) keyEquivalent:@""] setTarget:self];
    }
    
    return menu;
}

- (void)menuActionReply:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:SMEditorReplyKind_ReplyOne toAddress:nil];
}

- (void)menuActionReplyAll:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:SMEditorReplyKind_ReplyAll toAddress:nil];
}

- (void)menuActionForward:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:SMEditorReplyKind_Forward toAddress:nil];
}

- (void)menuActionDelete:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate appController] moveSelectedMessageThreadsToTrash];
}

- (void)menuActionMarkAsSeen:(id)sender {
    [self markMessageThreadsAsUnseen:NO];
}

- (void)menuActionMarkAsUnseen:(id)sender {
    [self markMessageThreadsAsUnseen:YES];
}

- (void)menuActionAddStar:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];

        if(messageThread != nil) {
            [self addStarToMessageThread:messageThread];
            
            [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)menuActionRemoveStar:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil) {
            [self removeStarFromMessageThread:messageThread];

            [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)toggleStarForSelected {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    BOOL allFlagged = YES;
    for(NSUInteger selectedRow = [_messageListTableView.selectedRowIndexes firstIndex]; selectedRow != NSNotFound; selectedRow = [_messageListTableView.selectedRowIndexes indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil && !messageThread.flagged) {
            allFlagged = NO;
            break;
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    BOOL addStar = (allFlagged ? NO : YES);
    for(NSUInteger selectedRow = [_messageListTableView.selectedRowIndexes firstIndex]; selectedRow != NSNotFound; selectedRow = [_messageListTableView.selectedRowIndexes indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil) {
            if(addStar) {
                [self addStarToMessageThread:messageThread];
            }
            else {
                [self removeStarFromMessageThread:messageThread];
            }

            [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [self reloadMessageList:YES];
}

- (void)markMessageThreadsAsUnseen:(BOOL)unseen {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil) {
            for(SMMessage *message in messageThread.messagesSortedByDate) {
                SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
                [appDelegate.messageThreadAccountProxy setMessageUnseen:messageThread message:message unseen:unseen];
                
                [messageThread updateThreadAttributesForMessageId:message.messageId];
            }

            [SMNotificationsController localNotifyMessageThreadUpdated:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark Opening message in window

- (void)openMessageInWindow:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> localFolder = messageListController.currentLocalFolder;
    
    if(localFolder == nil) {
        SM_LOG_INFO(@"no local folder");
        return;
    }
    
    SMMessageThread *messageThread = [localFolder.messageStorage messageThreadAtIndexByDate:_messageListTableView.clickedRow];

    if(messageThread == nil) {
        SM_LOG_INFO(@"messageThread is nil");
        return;
    }

    for(SMMessage *m in messageThread.messagesSortedByDate) {
        if(m.draft) {
            if(m.htmlBodyRendering != nil) {
                BOOL plainText = NO; // TODO: detect if the draft being opened is a plain text message, see issue #89 
                [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering plainText:plainText subject:m.subject to:[SMAddress mcoAddressesToAddressList:m.toAddressList] cc:[SMAddress mcoAddressesToAddressList:m.ccAddressList] bcc:nil draftUid:m.uid mcoAttachments:m.attachments editorKind:kUnfoldedDraftEditorContentsKind];
            }
            else {
                SM_LOG_DEBUG(@"TODO: handle messageToOpen.htmlBodyRendering is nil");
            }
            
            return;
        }
    }
    
    // Assume there's no draft, so open the message window in the readonly mode.
    
    [[appDelegate appController] openMessageThreadWindow:messageThread localFolder:localFolder];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent {
    if(theEvent.type == NSKeyDown && (theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask) == 0) {
        NSString *pressedChars = [theEvent characters];

        if([pressedChars length] == 1) {
            unichar pressedUnichar = [pressedChars characterAtIndex:0];
            
            if((pressedUnichar == NSDeleteCharacter) || (pressedUnichar == NSDeleteFunctionKey)) {
                SM_LOG_INFO(@"delete key pressed");

                [self menuActionDelete:self];
            }
            else if(pressedUnichar == 27) {
                SM_LOG_INFO(@"escape key pressed");
                
                // TODO: special case 1: editor is open
                //       see issue #115

                [self unselectCurrentMessageThread];
            }
        }
    }
}

- (void)unselectCurrentMessageThread {
    [self reloadMessageList:NO];
    [self changeSelectedMessageThread];
}

#pragma mark Cell selection

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    static NSString* const kRowIdentifier = @"MessageListRowView";
    SMMessageListRowView* rowView = [tableView makeViewWithIdentifier:kRowIdentifier owner:self];
    if (!rowView) {
        rowView = [[SMMessageListRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        rowView.identifier = kRowIdentifier;
    }
    
    rowView.row = row;

    return rowView;
}

@end
