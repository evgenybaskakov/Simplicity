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
#import "SMPreferencesController.h"
#import "SMAddressBookController.h"
#import "SMAbstractLocalFolder.h"
#import "SMFolder.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageListRowView.h"

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
    Boolean _immediateSelection;
    Boolean _mouseSelectionInProcess;
    Boolean _reloadDeferred;
    NSIndexSet *_selectedRowsWithMenu;
    NSMutableDictionary<NSString*, ScrollPosition*> *_folderScrollPositions;
    ScrollPosition *_currentFolderScrollPosition;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if(self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyFetched:) name:@"MessageBodyFetched" object:nil];
        
        _multipleSelectedMessageThreads = [NSMutableArray array];
        _folderScrollPositions = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)viewDidLoad {
    [_messageListTableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [_messageListTableView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    [_messageListTableView setDoubleAction:@selector(openMessageInWindow:)];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
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
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    NSUInteger selectedThreadsCount = (_selectedMessageThread != nil? 1 : _multipleSelectedMessageThreads.count);
    [[[appDelegate appController] messageThreadViewController] setMessageThread:_selectedMessageThread selectedThreadsCount:selectedThreadsCount];
}

- (void)delayChangeSelectedMessageThread {
    [self performSelector:@selector(changeSelectedMessageThread) withObject:nil afterDelay:0.3];
}

- (void)cancelChangeSelectedMessageThread {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(changeSelectedMessageThread) object:nil];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self cancelChangeSelectedMessageThread];

    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];

    if(selectedRows.count <= 1) {
        [_multipleSelectedMessageThreads removeAllObjects];

        NSInteger selectedRow = [_messageListTableView selectedRow];
        
        if(selectedRow >= 0) {
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
            id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
            NSAssert(currentFolder != nil, @"bad corrent folder");
            
            _selectedMessageThread = [currentFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
            
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
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
        id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
        NSAssert(currentFolder != nil, @"bad corrent folder");
        
        // TODO: optimize later
        [_multipleSelectedMessageThreads removeAllObjects];

        NSUInteger selectedRow = [selectedRows firstIndex];
        while(selectedRow != NSNotFound) {
            SMMessageThread *messageThread = [currentFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
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
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SM_LOG_DEBUG(@"tableView %@, datasource %@, delegate call: %@, row %ld", tableView, [tableView dataSource], [tableColumn identifier], row);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:row];

    if(messageThread == nil) {
        SM_LOG_DEBUG(@"row %ld, message thread is nil", row);
        return nil;
    }
    
    NSAssert([messageThread messagesCount], @"no messages in the thread");
    SMMessage *firstMessage = [messageThread messagesSortedByDate][0];
    
    SM_LOG_DEBUG(@"from '%@', subject '%@', unseen %u", [SMMessage parseAddress:firstMessage.fromAddress], firstMessage.subject, messageThread.unseen);

    SMMessageListCellView *view = [tableView makeViewWithIdentifier:@"MessageCell" owner:self];
    NSAssert(view != nil, @"view is nil");
    
    [view initFields];
    
    [view.fromTextField setStringValue:[SMMessage parseAddress:firstMessage.fromAddress]];
    [view.subjectTextField setStringValue:[firstMessage subject]];
    [view.dateTextField setStringValue:[firstMessage localizedDate]];

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
    [self setToggleButtonAlpha:view.starButton];
    
    [view setMessagesCount:messageThread.messagesCount];
    
    SMFolder *currentFolder = [appDelegate.currentMailboxController selectedFolder];
    NSArray *bookmarkColors = [[appController folderColorController] colorsForMessageThread:messageThread folder:currentFolder labels:nil];
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
    
    NSString *bodyPreview = [firstMessage bodyPreview];
    [view.messagePreviewTextField setStringValue:(bodyPreview != nil && bodyPreview.length > 0? bodyPreview : (firstMessage.hasData? @"Message has no content" : @""))];
    
    NSString *fromEmail = [firstMessage.fromAddress mailbox];
    NSImage *contactImage = [[appDelegate addressBookController] pictureForEmail:fromEmail];
    if(contactImage != nil) {
        view.contactImage.image = contactImage;
    }

    [_currentFolderScrollPosition.threadsAtRows setObject:messageThread forKey:[NSNumber numberWithUnsignedInteger:row]];
    
    return view;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
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
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
    
    if(currentFolder == nil) {
        return NO;
    }
    
    SMMessageThread *messageThread = _currentFolderScrollPosition.visibleMessageThreads[idx];
    NSUInteger threadIndex = [currentFolder.messageStorage getMessageThreadIndexByDate:messageThread];
    
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

- (void)reloadMessageList:(Boolean)preserveSelection updateScrollPosition:(BOOL)updateScrollPosition {
    if(updateScrollPosition) {
        [self saveScrollPosition];
        [self reloadMessageList:preserveSelection];
        [self restoreScrollPosition];
    }
    else {
        [self reloadMessageList:preserveSelection];
    }
}

- (void)reloadMessageList:(Boolean)preserveSelection {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
    
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
    if(currentFolder != nil) {
        _currentFolderScrollPosition = [_folderScrollPositions objectForKey:currentFolder.localName];
        
        if(_currentFolderScrollPosition == nil) {
            _currentFolderScrollPosition = [[ScrollPosition alloc] init];
            [_folderScrollPositions setObject:_currentFolderScrollPosition forKey:currentFolder.localName];
        }
        
        // after all is done, fix the currently selected
        // message cell, if needed
        if(preserveSelection) {
            id<SMAbstractMessageStorage> messageStorage = currentFolder.messageStorage;
            
            if(_selectedMessageThread != nil) {
                NSAssert(_multipleSelectedMessageThreads.count == 0, @"multiple messages selection not empty");

                NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:_selectedMessageThread];
                
                if(threadIndex != NSNotFound) {
                    [_messageListTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:threadIndex] byExtendingSelection:NO];
                    return;
                }
            } else {
                NSMutableIndexSet *threadIndexes = [NSMutableIndexSet indexSet];
                
                for(SMMessageThread *t in _multipleSelectedMessageThreads) {
                    NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:t];
                    
                    if(threadIndex != NSNotFound)
                        [threadIndexes addIndex:threadIndex];
                }

                if(threadIndexes.count != 0) {
                    [_messageListTableView selectRowIndexes:threadIndexes byExtendingSelection:NO];
                    return;
                }
            }
        }
    }

    [_messageListTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];

    [_multipleSelectedMessageThreads removeAllObjects];

    _selectedMessageThread = nil;
}

- (IBAction)updateMessagesNow:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];

    [messageListController cancelMessageListUpdate];
    [messageListController scheduleMessageListUpdate:YES];

    [_updatingMessagesProgressIndicator setHidden:NO];
    [_updatingMessagesProgressIndicator startAnimation:self];
}

- (IBAction)loadMoreMessages:(id)sender {
    SM_LOG_DEBUG(@"sender %@", sender);

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];

    id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
    if(currentFolder != nil && [currentFolder messageHeadersAreBeingLoaded] == NO) {
        [currentFolder increaseLocalFolderCapacity];
        [messageListController scheduleMessageListUpdate:YES];

        [_loadingMoreMessagesProgressIndicator setHidden:NO];
        [_loadingMoreMessagesProgressIndicator startAnimation:self];
    }
}

- (void)messageHeadersSyncFinished:(Boolean)hasUpdates updateScrollPosition:(BOOL)updateScrollPosition {
    [self stopProgressIndicators];

    if(hasUpdates) {
        [self reloadMessageList:YES updateScrollPosition:updateScrollPosition];

        SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
        [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    }
}

- (void)messageBodyFetched:(NSNotification *)notification {
    NSString *localFolder;
    uint32_t uid;
    int64_t threadId;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchedParams:notification localFolder:&localFolder uid:&uid threadId:&threadId account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
        id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
        
        if(currentFolder != nil && [currentFolder.localName isEqualToString:localFolder]) {
            NSAssert([(NSObject*)currentFolder.messageStorage isKindOfClass:[SMMessageStorage class]], @"current folder is unified");
            SMMessageThread *messageThread = [(SMMessageStorage*)currentFolder.messageStorage messageThreadById:threadId];
            
            if(messageThread != nil) {
                if([messageThread updateThreadAttributesFromMessageUID:uid]) {
                    NSUInteger threadIndex = [currentFolder.messageStorage getMessageThreadIndexByDate:messageThread];
                    
                    if(threadIndex != NSNotFound) {
                        [_messageListTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:threadIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                    }
                }
            }
            else {
                SM_LOG_WARNING(@"Message body fetched (uid %u, thread id %llu), but message thread not found", uid, threadId);
            }
        }
    }
}

- (void)stopProgressIndicators {
    [_updatingMessagesProgressIndicator stopAnimation:self];
    [_loadingMoreMessagesProgressIndicator stopAnimation:self];
}

- (void)moveSelectedMessageThreadsToFolder:(NSString*)remoteFolderName {
    SM_LOG_DEBUG(@"to remote folder %@", remoteFolderName);
    
    // 1. stop current sync, disable further syncs
    // 2. remote selected message threads from the list
    // 3. clear currently selected message
    // 4. start copy op
    // 5. once copy done, start 'add delete flag' op
    // 6. once flagging is done, start 'expunge folder' op
    // 7. once expunge is done, enable and start sync
    // err-1. if copy op fails, retry N times, then revert the changes made to the message list
    // err-2. if flagging op fails, retry N times, then register the op and put it to background
    // err-3. if expunge op fails, retry N times, then register the op and put it to background
    // TODO: save transaction history in a registry on disk, so these ops could be retried even after app restart

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];

    if(_selectedMessageThread == nil && _multipleSelectedMessageThreads.count == 0 && _draggedMessageThread == nil) {
        SM_LOG_DEBUG(@"no message threads selected for moving");
        return;
    }

    NSArray *messageThreadsToMove = _selectedMessageThread != nil? [NSArray arrayWithObject:_selectedMessageThread] : _multipleSelectedMessageThreads.count > 0? [NSArray arrayWithArray:_multipleSelectedMessageThreads] : [NSArray arrayWithObject:_draggedMessageThread];
    
    id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");

    if([currentFolder moveMessageThreads:messageThreadsToMove toRemoteFolder:remoteFolderName]) {
        NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];

        if(selectedRows.count > 0) {
            // Move the selection down after the message thread is deleted from the list.
            NSUInteger nextRow = selectedRows.firstIndex;
            _selectedMessageThread = [currentFolder.messageStorage messageThreadAtIndexByDate:nextRow];
            
            // If there's no down, move the selection up.
            if(_selectedMessageThread == nil && nextRow > 0) {
                nextRow--;
                _selectedMessageThread = [currentFolder.messageStorage messageThreadAtIndexByDate:nextRow];
            }

            if(_selectedMessageThread != nil) {
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:nextRow];
                [_messageListTableView selectRowIndexes:indexSet byExtendingSelection:NO];
            }
        }
        else {
            _selectedMessageThread = nil;
        }

        [self changeSelectedMessageThread];

        _draggedMessageThread = nil;
        _mouseSelectionInProcess = NO;
        _immediateSelection = NO;
        _reloadDeferred = NO;

        [self reloadMessageList:(_selectedMessageThread != nil? YES : NO)];
    }
    else {
        SM_LOG_DEBUG(@"Could not move message threads from %@ to %@", currentFolder.localName, remoteFolderName);
    }
}

#pragma mark Messages drag and drop support

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
    // only permit dragging messages from the message list

    if(aTableView == _messageListTableView) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
        [pboard setData:data forType:NSStringPboardType];

        if(_selectedMessageThread == nil && _multipleSelectedMessageThreads.count == 0) {
            NSAssert(rowIndexes.count == 1, @"multiple rows (%lu) are dragged without selection", rowIndexes.count);

            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
            id<SMAbstractLocalFolder> currentFolder = [messageListController currentLocalFolder];
            NSAssert(currentFolder != nil, @"no current folder");

            _draggedMessageThread = [currentFolder.messageStorage messageThreadAtIndexByDate:rowIndexes.firstIndex];
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

    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
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
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
}

- (void)addStarToMessageThread:(SMMessageThread*)messageThread {
    //
    // TODO: Use not just the first message, but the first message that belongs to this remote folder
    //
    SMMessage *message = messageThread.messagesSortedByDate[0];
    
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageFlagged:message flagged:YES];
    
    [messageThread updateThreadAttributesFromMessageUID:message.uid];
}

- (void)removeStarFromMessageThread:(SMMessageThread*)messageThread {
    //
    // Gmail logic: remove the star from all messages in the thread.
    //
    for(SMMessage *message in messageThread.messagesSortedByDate) {
        //
        // TODO: Optimize by using the bulk API for setting IMAP flags
        //
        SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
        [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageFlagged:message flagged:NO];

        [messageThread updateThreadAttributesFromMessageUID:message.uid];
    }
}

- (IBAction)toggleUnseenAction:(id)sender {
    NSButton *button = (NSButton*)sender;
    [self setToggleButtonAlpha:button];
    
    NSInteger row = button.tag;
    
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
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
            [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageUnseen:message unseen:NO];
            [messageThread updateThreadAttributesFromMessageUID:message.uid];
        }
    }
    else {
        //
        // TODO: Use not just the first message, but the first message that belongs to this remote folder
        //
        SMMessage *message = messageThread.messagesSortedByDate[0];
        
        [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageUnseen:message unseen:!message.unseen];
        [messageThread updateThreadAttributesFromMessageUID:message.uid];
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
}

#pragma mark Context menu creation

- (NSMenu*)menuForRow:(NSInteger)row {
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
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
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:@"Reply" toAddress:nil];
}

- (void)menuActionReplyAll:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:@"ReplyAll" toAddress:nil];
}

- (void)menuActionForward:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:nil replyKind:@"Forward" toAddress:nil];
}

- (void)menuActionDelete:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] moveSelectedMessageThreadsToTrash];
}

- (void)menuActionMarkAsSeen:(id)sender {
    [self markMessageThreadsAsUnseen:NO];
}

- (void)menuActionMarkAsUnseen:(id)sender {
    [self markMessageThreadsAsUnseen:YES];
}

- (void)menuActionAddStar:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];

        if(messageThread != nil) {
            [self addStarToMessageThread:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)menuActionRemoveStar:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil) {
            [self removeStarFromMessageThread:messageThread];
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)markMessageThreadsAsUnseen:(Boolean)unseen {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    id<SMAbstractLocalFolder> currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSUInteger selectedRow = [_selectedRowsWithMenu firstIndex]; selectedRow != NSNotFound; selectedRow = [_selectedRowsWithMenu indexGreaterThanIndex:selectedRow]) {
        SMMessageThread *messageThread = [currentLocalFolder.messageStorage messageThreadAtIndexByDate:selectedRow];
        
        if(messageThread != nil) {
            for(SMMessage *message in messageThread.messagesSortedByDate) {
                [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageUnseen:message unseen:unseen];
                [messageThread updateThreadAttributesFromMessageUID:message.uid];
            }
        }
        else {
            SM_LOG_ERROR(@"message thread at row %lu not found", selectedRow);
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark Opening message in window

- (void)openMessageInWindow:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
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
                Boolean plainText = NO; // TODO: detect if the draft being opened is a plain text message, see issue #89 
                [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering plainText:plainText subject:m.subject to:m.toAddressList cc:m.ccAddressList bcc:nil draftUid:m.uid mcoAttachments:m.attachments];
            }
            else {
                SM_LOG_DEBUG(@"TODO: handle messageToOpen.htmlBodyRendering is nil");
            }
            
            return;
        }
    }
    
    // Assume there's no draft, so open the message window in the readonly mode.
    
    [[appDelegate appController] openMessageWindow:messageThread];
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
                //
                
                [self reloadMessageList:NO];
                [self changeSelectedMessageThread];
            }
        }
    }
}

#pragma mark Cell selection

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [[SMMessageListRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

@end
