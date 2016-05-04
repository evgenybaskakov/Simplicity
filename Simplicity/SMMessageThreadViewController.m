
//
//  SMMessageThreadViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/2/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMUserAccount.h"
#import "SMNotificationsController.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadCell.h"
#import "SMMessageThreadCellViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadInfoViewController.h"
#import "SMMessageBodyViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessagePlaceholderViewController.h"
#import "SMLocalFolder.h"
#import "SMMailbox.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWebView.h"
#import "SMAddressFieldViewController.h"
#import "SMTokenField.h"
#import "SMFlippedView.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMStringUtils.h"
#import "SMAddress.h"

static const CGFloat MIN_EDITOR_HEIGHT = 200;
static const CGFloat MAX_EDITOR_HEIGHT = 600;
static const CGFloat CELL_SPACING = -1;

@interface SMMessageThreadViewController()
- (void)messageBodyFetched:(NSNotification *)notification;
- (void)updateMessageView:(uint32_t)uid threadId:(uint64_t)threadId;
@end

@implementation SMMessageThreadViewController {
    NSScrollView *_messageThreadView;
    SMMessagePlaceholderViewController *_messagePlaceHolderViewController;
    SMMessageThreadInfoViewController *_messageThreadInfoViewController;
    SMMessageEditorViewController *_messageEditorViewController;
    SMMessageThreadCellViewController *_cellViewControllerToReply;
    NSMutableArray *_cells;
    NSView *_contentView;
    Boolean _findContentsActive;
    NSString *_currentStringToFind;
    Boolean _currentStringToFindMatchCase;
    Boolean _stringOccurrenceMarked;
    NSUInteger _stringOccurrenceMarkedCellIndex;
    NSUInteger _stringOccurrenceMarkedResultIndex;
    NSUInteger _firstVisibleCell, _lastVisibleCell;
    Boolean _cellsArranged;
    Boolean _cellsUpdateStarted;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        NSVisualEffectView *rootView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        rootView.translatesAutoresizingMaskIntoConstraints = NO;
        rootView.state = NSVisualEffectStateActive;
        rootView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        rootView.material = NSVisualEffectMaterialLight;
        
        [self setView:rootView];
        
        _messagePlaceHolderViewController = [[SMMessagePlaceholderViewController alloc] initWithNibName:@"SMMessagePlaceholderViewController" bundle:nil];
        _messagePlaceHolderViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        _messagePlaceHolderViewController.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        _messageThreadView = [[NSScrollView alloc] init];
        _messageThreadView.borderType = NSNoBorder;
        _messageThreadView.hasVerticalScroller = YES;
        _messageThreadView.hasHorizontalScroller = NO;
        _messageThreadView.backgroundColor = [NSColor clearColor];
        _messageThreadView.translatesAutoresizingMaskIntoConstraints = YES;
        _messageThreadView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        _cells = [NSMutableArray new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyFetched:) name:@"MessageBodyFetched" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageViewFrameLoaded:) name:@"MessageViewFrameLoaded" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(composeMessageReply:) name:@"ComposeMessageReply" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteEditedMessageDraft:) name:@"DeleteEditedMessageDraft" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageSent:) name:@"MessageSent" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteMessage:) name:@"DeleteMessage" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMessageCellUnreadFlag:) name:@"ChangeMessageUnreadFlag" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMessageCellFlaggedFlag:) name:@"ChangeMessageFlaggedFlag" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveAttachments:) name:@"SaveAttachments" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveAttachmentsToDownloads:) name:@"SaveAttachmentsToDownloads" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageEditorContentHeightChanged:) name:@"MessageEditorContentHeightChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageThreadCellHeightChanged:) name:@"MessageThreadCellHeightChanged" object:nil];
        
        [self hideCurrentMessageThread:0];
    }
    
    return self;
}

- (void)messageThreadViewWillClose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Setting new message threads

- (SMMessageThreadCellViewController*)createMessageThreadCell:(SMMessage*)message collapsed:(Boolean)collapsed {
    SMMessageThreadCellViewController *messageThreadCellViewController = [[SMMessageThreadCellViewController alloc] init:self collapsed:collapsed];
    
    [messageThreadCellViewController setMessage:message];
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    if([messageThreadCellViewController loadMessageBody]) {
        [appDelegate.currentAccount fetchMessageInlineAttachments:message];
    } else {
        SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
        
        [messageListController fetchMessageBodyUrgently:message.uid messageDate:message.date remoteFolder:[message remoteFolder] threadId:[_currentMessageThread threadId]];
    }
    
    return messageThreadCellViewController;
}

- (void)closeEmbeddedEditor:(Boolean)saveDraft {
    if(_messageEditorViewController != nil) {
        // TODO: it looks like that's not enough (unreg token notifi. as well)
        
        [_messageEditorViewController.view removeFromSuperview];
        [_messageEditorViewController closeEditor:saveDraft];
        
        _messageEditorViewController = nil;
        _cellViewControllerToReply = nil;
    }
}

- (void)setMessageThread:(SMMessageThread*)messageThread selectedThreadsCount:(NSUInteger)selectedThreadsCount {
    if(messageThread == nil) {
        [self hideCurrentMessageThread:selectedThreadsCount];
    }

    if(_currentMessageThread == messageThread)
        return;
    
    [self closeEmbeddedEditor:YES];
    
    _currentMessageThread = messageThread;

    if(_currentMessageThread != nil) {
        [self showCurrentMessageThread];
    }

    if(_messageThreadInfoViewController == nil) {
        _messageThreadInfoViewController = [[SMMessageThreadInfoViewController alloc] init];
        
        NSView *infoView = [_messageThreadInfoViewController view];
        NSAssert(infoView != nil, @"no info view");
        
        infoView.translatesAutoresizingMaskIntoConstraints = YES;
    }
    
    [_messageThreadInfoViewController setMessageThread:_currentMessageThread];
    
    [_cells removeAllObjects];
    
    _contentView = [[SMFlippedView alloc] initWithFrame:_messageThreadView.frame];
    _contentView.translatesAutoresizingMaskIntoConstraints = YES;
    
    [_messageThreadView setDocumentView:_contentView];
    
    [[_messageThreadView contentView] setPostsBoundsChangedNotifications:YES];
    [[_messageThreadView contentView] setPostsFrameChangedNotifications:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[_messageThreadView contentView]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:[_messageThreadView contentView]];
    
    if(_currentMessageThread != nil) {
        [_contentView addSubview:_messageThreadInfoViewController.view];
        
        NSAssert(_currentMessageThread.messagesCount > 0, @"no messages in message thread");
        
        NSArray *messages = [_currentMessageThread messagesSortedByDate];
        
        _cells = [NSMutableArray arrayWithCapacity:messages.count];
        
        NSUInteger lastUnseenMessageIdx = NSUIntegerMax;
        if(_currentMessageThread.unseen) {
            for(NSUInteger i = messages.count; i > 0;) {
                SMMessage *message = messages[--i];
                
                if(message.unseen) {
                    lastUnseenMessageIdx = i;
                    break;
                }
            }
        }
        
        for(NSUInteger i = 0; i < messages.count; i++) {
            Boolean collapsed = (messages.count == 1? NO : (_currentMessageThread.unseen? i != lastUnseenMessageIdx : i > 0));
            SMMessageThreadCellViewController *viewController = [self createMessageThreadCell:messages[i] collapsed:collapsed];
            
            [viewController enableCollapse:(messages.count > 1)];
            viewController.shouldDrawBottomLineWhenUncollapsed = (i != messages.count-1? YES : NO);
            viewController.cellIndex = i;
            
            [_contentView addSubview:[viewController view]];
            
            _cells[i] = [[SMMessageThreadCell alloc] initWithMessage:messages[i] viewController:viewController];
        }
        
        [self updateCellFrames];
        
        if(lastUnseenMessageIdx != NSUIntegerMax) {
            SMMessageThreadCell *cell = _cells[lastUnseenMessageIdx];
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            
            [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageUnseen:cell.message unseen:NO];
            [_currentMessageThread updateThreadAttributesFromMessageUID:cell.message.uid];
            
            [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
        }
    }
    else {
        [_messageThreadInfoViewController.view removeFromSuperview];
    }
    
    // on every message thread switch, we hide the find contents panel
    // because it is presumably needed only when the user means to search the particular message thread
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hideFindContentsPanel];
}

- (void)showCurrentMessageThread {
    NSView *rootView = self.view;
    
    [_messagePlaceHolderViewController.view removeFromSuperview];

    [rootView addSubview:_messageThreadView];
    _messageThreadView.frame = rootView.frame;
}

- (void)hideCurrentMessageThread:(NSUInteger)selectedThreadsCount {
    NSView *rootView = self.view;

    [_messageThreadView removeFromSuperview];

    _messagePlaceHolderViewController.selectedMessagesLabel.stringValue = (selectedThreadsCount == 0? @"No messages selected" : [NSString stringWithFormat:@"%lu messages selected", selectedThreadsCount]);
    
    [rootView addSubview:_messagePlaceHolderViewController.view];
    _messagePlaceHolderViewController.view.frame = rootView.frame;
}

#pragma mark Building visual layout of message threads

- (void)updateMessageThread {
    if(_currentMessageThread == nil)
        return;
    
    NSAssert(_cells != nil, @"no cells in the current thread");
    
    NSArray *newMessages = [_currentMessageThread messagesSortedByDate];
    
    if(newMessages.count > 0) {
        // check whether messages did not change
        if(newMessages.count == _cells.count) {
            Boolean equal = YES;
            
            for(NSInteger i = 0; i < _cells.count; i++) {
                if(newMessages[i] != ((SMMessageThreadCell*)_cells[i]).message) {
                    equal = NO;
                    break;
                }
            }
            
            if(equal) {
                for(NSInteger i = 0; i < _cells.count; i++) {
                    SMMessageThreadCell *cell = _cells[i];
                    [cell.viewController updateMessage];
                }
                
                return;
            }
        }
        
        SM_LOG_DEBUG(@"message thread id %llu has been updated (old message count %lu, new %ld)", _currentMessageThread.threadId, _cells.count, _currentMessageThread.messagesCount);
        
        // remove old (vanished) messages
        for(NSInteger t = _cells.count; t > 0; t--) {
            NSInteger i = t-1;
            SMMessageThreadCell *cell = _cells[i];
            
            // TODO: use the sorting info for fast search
            if(![newMessages containsObject:cell.message]) {
                // if there's a reply to the vanished message being composed,
                // just clear the cell marker; the editor will be moved to the top
                // of the message thread on frame updatess
                if(_cellViewControllerToReply == cell.viewController) {
                    _cellViewControllerToReply = nil;
                }
                
                // Physically remove the cell and its subview.
                [cell.viewController.view removeFromSuperview];
                [_cells removeObjectAtIndex:i];
                
                // Adjust the search marker position, if any.
                if(_stringOccurrenceMarked) {
                    if(_stringOccurrenceMarkedCellIndex == i) {
                        [self clearStringOccurrenceMarkIndex];
                    } else if(i < _stringOccurrenceMarkedCellIndex) {
                        _stringOccurrenceMarkedCellIndex--;
                    }
                }
            }
        }
        
        // add new messages and update existing
        NSMutableArray *updatedCells = [NSMutableArray arrayWithCapacity:newMessages.count];
        
        for(NSInteger i = 0, j = 0; i < newMessages.count; i++) {
            SMMessage *newMessage = newMessages[i];
            
            if(j >= _cells.count || ((SMMessageThreadCell*)_cells[j]).message != newMessage) {
                SMMessageThreadCellViewController *viewController = [self createMessageThreadCell:newMessage collapsed:YES];
                
                [_contentView addSubview:[viewController view]];
                
                updatedCells[i] = [[SMMessageThreadCell alloc] initWithMessage:newMessage viewController:viewController];
            } else {
                SMMessageThreadCell *cell = _cells[j++];
                
                [cell.viewController updateMessage];
                
                updatedCells[i] = cell;
            }
            
            SMMessageThreadCell *cell = updatedCells[i];
            cell.viewController.cellIndex = i;
            
            [cell.viewController enableCollapse:(newMessages.count > 1)];
            
            if(newMessages.count == 1)
                [cell.viewController setCollapsed:NO];
        }
        
        // populate the updated view
        _cells = updatedCells;
        
        [self updateCellFrames];
        
        [_messageThreadInfoViewController updateMessageThread];
    } else {
        SM_LOG_DEBUG(@"message thread id %llu is empty", _currentMessageThread.threadId);
        
        [_cells removeAllObjects];
        [_contentView setSubviews:[NSArray array]];
        
        _currentMessageThread = nil;
        
        [_messageThreadInfoViewController setMessageThread:nil];
    }
}

- (Boolean)shouldUseFullHeightForFirstCell {
    if(_messageEditorViewController == nil && _cells.count == 1) {
        SMMessageThreadCell *firstCell = _cells[0];
        
        if(!firstCell.viewController.mainFrameLoaded) {
            // Reasoning: if the message is not yet loaded (thus we don't know its
            // real height), it should fit the window. The exceptions are when
            // there are other messages (cells) in this thread, or when there's
            // an embedded message editor opened. (May want to reconsider.)
            return YES;
        }
    }
    
    return NO;
}

- (void)updateCellFrames {
    if(_cells.count == 0) {
        SM_LOG_DEBUG(@"no cells");
        return;
    }
    
    _cellsUpdateStarted = YES;
    
    CGFloat fullHeight = 0;
    CGFloat editorHeight = 0;
    
    if(_messageEditorViewController != nil) {
        editorHeight = MAX(MIN_EDITOR_HEIGHT, MIN(_messageEditorViewController.editorFullHeight, MAX_EDITOR_HEIGHT));
        
        fullHeight += editorHeight;
        fullHeight += CELL_SPACING;
    }
    
    if([self shouldUseFullHeightForFirstCell]) {
        fullHeight += _contentView.frame.size.height;
    }
    else {
        fullHeight += [SMMessageThreadInfoViewController infoHeaderHeight];
        
        for(NSInteger i = 0; i < _cells.count; i++) {
            SMMessageThreadCell *cell = _cells[i];
            fullHeight += (CGFloat)cell.viewController.cellHeight;
            
            if(i + 1 < _cells.count)
                fullHeight += CELL_SPACING;
        }
    }
    
    _contentView.frame = NSMakeRect(0, 0, _contentView.frame.size.width, fullHeight);
    _contentView.autoresizingMask = NSViewWidthSizable;
    
    if([self shouldUseFullHeightForFirstCell]) {
        _contentView.autoresizingMask |= NSViewHeightSizable;
    }
    
    NSView *infoView = [_messageThreadInfoViewController view];
    NSAssert(infoView != nil, @"no info view");
    
    infoView.frame = NSMakeRect(-1, 0, _contentView.frame.size.width+2, [SMMessageThreadInfoViewController infoHeaderHeight]);
    infoView.autoresizingMask = NSViewWidthSizable;
    
    CGFloat ypos = infoView.bounds.size.height + CELL_SPACING;
    
    for(NSInteger i = 0; i < _cells.count; i++) {
        SMMessageThreadCell *cell = _cells[i];
        
        NSAssert(cell.viewController != nil, @"cell.viewController is nil");
        if(_messageEditorViewController != nil) {
            if((_cellViewControllerToReply == nil && i == 0) || (_cellViewControllerToReply == cell.viewController)) {
                if(i == 0) {
                    // Avoid negative overlapping between the editor, because its frame
                    // is already borderless.
                    ypos -= CELL_SPACING;
                }
                
                // Note that the editor width doesn't have to exceed the content view width,
                // because it already does.
                [_messageEditorViewController setEditorFrame:NSMakeRect(0, ypos, infoView.frame.size.width, editorHeight)];
                ypos += editorHeight + CELL_SPACING;
            }
        }
        
        NSView *subview = cell.viewController.view;
        subview.translatesAutoresizingMaskIntoConstraints = YES;
        subview.autoresizingMask = NSViewWidthSizable;
        
        if([self shouldUseFullHeightForFirstCell]) {
            subview.frame = NSMakeRect(-1, ypos, infoView.frame.size.width+2, fullHeight);
            
            NSAssert(!cell.viewController.collapsed, @"cell must not be collapsed");
            
            [cell.viewController adjustCellHeightToFitContentResizeable:YES];
        } else {
            subview.frame = NSMakeRect(-1, ypos, infoView.frame.size.width+2, cell.viewController.cellHeight);
            
            if(!cell.viewController.collapsed) {
                [cell.viewController adjustCellHeightToFitContentResizeable:NO];
            }
        }
        
        ypos += cell.viewController.cellHeight + CELL_SPACING;
    }
    
    _cellsUpdateStarted = NO;
    _cellsArranged = NO;
    
    [self arrangeVisibleCells];
}

- (void)updateMessageView:(uint32_t)uid threadId:(uint64_t)threadId {
    if(_currentMessageThread == nil || _currentMessageThread.threadId != threadId)
        return;
    
    // TODO: optimize search?
    for(NSInteger i = 0; i < _cells.count; i++) {
        SMMessageThreadCell *cell = _cells[i];
        SMMessage *message = cell.message;
        
        if(message.uid == uid) {
            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            [appDelegate.currentAccount fetchMessageInlineAttachments:message];
            
            [cell.viewController updateMessage];
            
            if(![cell.viewController loadMessageBody]) {
                NSAssert(FALSE, @"message uid %u (thread id %lld) fetched with no body!!!", uid, threadId);
            }
            
            return;
        }
    }
    
    SM_LOG_DEBUG(@"message uid %u doesn't belong to thread id %lld", uid, threadId);
}

#pragma mark Cells collapsing / uncollapsing

- (void)setCellCollapsed:(Boolean)collapsed cellIndex:(NSUInteger)cellIndex {
    NSAssert(cellIndex < _cells.count, @"bad index %lu", cellIndex);
    
    SMMessageThreadCell *cell = _cells[cellIndex];
    
    if(_findContentsActive) {
        if(collapsed) {
            [cell.viewController removeAllHighlightedOccurrencesOfString];
            
            if(_stringOccurrenceMarked && _stringOccurrenceMarkedCellIndex == cellIndex)
                [self clearStringOccurrenceMarkIndex];
        } else {
            [cell.viewController highlightAllOccurrencesOfString:_currentStringToFind matchCase:_currentStringToFindMatchCase];
        }
    }
    
    // If the cell is being uncollapsed while the message is unread,
    // mark is as read; then update the message thread and the message
    // list to immediately reflect the changes.
    if(!collapsed && cell.message.unseen) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        
        [[[appDelegate.currentAccount messageListController] currentLocalFolder] setMessageUnseen:cell.message unseen:NO];
        [_currentMessageThread updateThreadAttributesFromMessageUID:cell.message.uid];
        
        [self updateMessageThread];
        
        [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
    }
}

- (void)collapseAll {
    if(_currentMessageThread == nil)
        return;
    
    if(_cells.count > 1) {
        for(SMMessageThreadCell *cell in _cells) {
            [cell.viewController setCollapsed:YES];
        }
    } else {
        SMMessageThreadCell *cell = _cells[0];
        
        NSAssert(!cell.viewController.collapsed, @"single cell is collapsed");
    }
    
    [self updateCellFrames];
}

- (void)uncollapseAll {
    if(_currentMessageThread == nil)
        return;
    
    for(SMMessageThreadCell *cell in _cells) {
        [cell.viewController setCollapsed:NO];
    }
    
    [self updateCellFrames];
}

#pragma mark Scrolling notifications

- (void)arrangeVisibleCells {
    if(_cellsUpdateStarted)
        return;
    
    if(_cells.count == 0)
        return;
    
    if(!_cellsArranged) {
        for(SMMessageThreadCell *cell in _cells) {
            [cell.viewController.view removeFromSuperview];
        }
        
        _firstVisibleCell = 0;
        _lastVisibleCell = 0;
        
        SMMessageThreadCell *cell = _cells[0];
        [_contentView addSubview:cell.viewController.view];
    }
    
    NSAssert(_firstVisibleCell <= _lastVisibleCell, @"bad _firstVisibleCell %lu, _lastVisibleCell %lu", _firstVisibleCell, _lastVisibleCell);
    NSAssert(_lastVisibleCell < _cells.count, @"bad _lastVisibleCell %lu, _cells.count %lu", _lastVisibleCell, _cells.count);
    
    NSRect visibleRect = [[_messageThreadView contentView] documentVisibleRect];
    
    const NSUInteger oldFirstVisibleCell = _firstVisibleCell;
    const NSUInteger oldLastVisibleCell = _lastVisibleCell;
    
    SMMessageThreadCell *firstCell = _cells[_firstVisibleCell];
    
    while(_firstVisibleCell > 0 && firstCell.viewController.view.frame.origin.y > visibleRect.origin.y) {
        firstCell = _cells[--_firstVisibleCell];
    }
    
    while(_firstVisibleCell + 1 < _cells.count && firstCell.viewController.view.frame.origin.y + firstCell.viewController.cellHeight <= visibleRect.origin.y) {
        //TODO: should we?
        //      if(!firstCell.viewController.collapsed)
        [firstCell.viewController.view removeFromSuperview];
        
        firstCell = _cells[++_firstVisibleCell];
    }
    
    if(_firstVisibleCell > _lastVisibleCell)
        _lastVisibleCell = _firstVisibleCell;
    
    SMMessageThreadCell *lastCell = _cells[_lastVisibleCell];
    
    while(_lastVisibleCell + 1 < _cells.count && lastCell.viewController.view.frame.origin.y + lastCell.viewController.cellHeight < visibleRect.origin.y + visibleRect.size.height) {
        lastCell = _cells[++_lastVisibleCell];
    }
    
    while(_lastVisibleCell > 0 && lastCell.viewController.view.frame.origin.y > visibleRect.origin.y + visibleRect.size.height) {
        //TODO: should we?
        //      if(!lastCell.viewController.collapsed)
        [lastCell.viewController.view removeFromSuperview];
        
        lastCell = _cells[--_lastVisibleCell];
    }
    
    NSAssert(_firstVisibleCell <= _lastVisibleCell, @"bad _firstVisibleCell %lu, _lastVisibleCell %lu", _firstVisibleCell, _lastVisibleCell);
    
    if(_firstVisibleCell < oldFirstVisibleCell) {
        if(oldFirstVisibleCell <= _lastVisibleCell)
            [self showCellsRegion:_firstVisibleCell toInclusive:oldFirstVisibleCell - 1];
        else
            [self showCellsRegion:_firstVisibleCell toInclusive:_lastVisibleCell];
    }
    
    if(_lastVisibleCell > oldLastVisibleCell) {
        if(_firstVisibleCell <= oldLastVisibleCell)
            [self showCellsRegion:oldLastVisibleCell + 1 toInclusive:_lastVisibleCell];
        else
            [self showCellsRegion:_firstVisibleCell toInclusive:_lastVisibleCell];
    }
    
    _cellsArranged = YES;
}

- (void)showCellsRegion:(NSUInteger)from toInclusive:(NSUInteger)to {
    for(NSUInteger i = from; i <= to; i++) {
        SMMessageThreadCell *cell = _cells[i];
        
        if(cell.viewController.view.superview == nil) {
            if([self shouldUseFullHeightForFirstCell]) {
                [cell.viewController.view setFrameSize:NSMakeSize(_contentView.frame.size.width+2, _contentView.frame.size.height)];
            }
            else {
                [cell.viewController.view setFrameSize:NSMakeSize(_contentView.frame.size.width+2, cell.viewController.cellHeight)];
            }
            
            [_contentView addSubview:cell.viewController.view];
        }
    }
}

- (void)viewBoundsDidChange:(NSNotification *)notification {
    [self arrangeVisibleCells];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    [self updateCellFrames];
}

#pragma mark Processing incoming notifications

- (void)messageBodyFetched:(NSNotification *)notification {
    uint32_t uid;
    int64_t threadId;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchedParams:notification localFolder:nil uid:&uid threadId:&threadId account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        [self updateMessageView:uid threadId:threadId];
    }
}

- (void)messageViewFrameLoaded:(NSNotification *)notification {
    uint32_t uid;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageViewFrameLoadedParams:notification uid:&uid account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        // TODO: optimize by adding a NSUndexSet with uids
        for(NSInteger i = 0; i < _cells.count; i++) {
            SMMessageThreadCell *cell = _cells[i];
            
            // Logic: if the message whose html body is just loaded is contained in this
            // message thread, and it is uncollapsed, cell heights may need to be adjusted.
            // TODO: maybe skip real frames update, if this cell is invisible?
            if(cell.message.uid == uid && !cell.viewController.collapsed) {
                [self updateCellFrames];
                break;
            }
        }
    }
}

#pragma mark Finding messages contents

- (void)findContents:(NSString*)stringToFind matchCase:(Boolean)matchCase forward:(Boolean)forward {
    NSAssert(_currentMessageThread != nil, @"_currentMessageThread == nil");
    NSAssert(_cells.count > 0, @"no cells");
    
    SMMessageThreadCell *markedCell = nil;
    
    if((_currentStringToFind != nil && ![_currentStringToFind isEqualToString:stringToFind]) || !_stringOccurrenceMarked) {
        // this is the case when there is no marked occurrence or the user has lost it
        // which can happen if the message cell is collapsed or vanished due to update
        // so just remove any stale mark and mark the first occurrence in the first cell
        // that has at least one
        
        if(_stringOccurrenceMarked) {
            NSAssert(_stringOccurrenceMarkedCellIndex < _cells.count, @"_stringOccurrenceMarkedCellIndex %lu, cells count %lu", _stringOccurrenceMarkedCellIndex, _cells.count);
            
            SMMessageThreadCell *cell = _cells[_stringOccurrenceMarkedCellIndex];
            [cell.viewController removeMarkedOccurrenceOfFoundString];
            
            _stringOccurrenceMarked = NO;
        }
        
        for(NSUInteger i = 0; i < _cells.count; i++) {
            SMMessageThreadCell *cell = _cells[i];
            
            if(!cell.viewController.collapsed) {
                [cell.viewController highlightAllOccurrencesOfString:stringToFind matchCase:matchCase];
                
                if(!_stringOccurrenceMarked) {
                    if(cell.viewController.stringOccurrencesCount > 0) {
                        _stringOccurrenceMarked = YES;
                        _stringOccurrenceMarkedCellIndex = i;
                        _stringOccurrenceMarkedResultIndex = 0;
                        
                        [cell.viewController markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
                        
                        markedCell = cell;
                    }
                }
            }
        }
        
        _currentStringToFind = stringToFind;
        _currentStringToFindMatchCase = matchCase;
    } else {
        // this is the case when there is a marked occurrence already
        // so we just need to move it forward or backwards
        // just scan the cells in the corresponsing direction and choose the right place
        
        NSAssert(_stringOccurrenceMarked, @"string occurrence not marked");
        NSAssert(_stringOccurrenceMarkedCellIndex < _cells.count, @"_stringOccurrenceMarkedCellIndex %lu, cells count %lu", _stringOccurrenceMarkedCellIndex, _cells.count);
        
        SMMessageThreadCell *cell = _cells[_stringOccurrenceMarkedCellIndex];
        NSAssert(!cell.viewController.collapsed, @"cell with marked string is collapsed");
        
        if(forward && _stringOccurrenceMarkedResultIndex+1 < cell.viewController.stringOccurrencesCount) {
            [cell.viewController markOccurrenceOfFoundString:(++_stringOccurrenceMarkedResultIndex)];
        } else if(!forward && _stringOccurrenceMarkedResultIndex > 0) {
            [cell.viewController markOccurrenceOfFoundString:(--_stringOccurrenceMarkedResultIndex)];
        } else {
            [cell.viewController removeMarkedOccurrenceOfFoundString];
            
            Boolean wrap = NO;
            for(NSUInteger i = _stringOccurrenceMarkedCellIndex;;) {
                if(forward) {
                    if(i == _cells.count-1) {
                        if(wrap) {
                            [self clearStringOccurrenceMarkIndex];
                            break;
                        } else {
                            wrap = YES;
                            i = 0;
                        }
                    } else {
                        i++;
                    }
                } else {
                    if(i == 0) {
                        if(wrap) {
                            [self clearStringOccurrenceMarkIndex];
                            break;
                        } else {
                            wrap = YES;
                            i = _cells.count-1;
                        }
                    } else {
                        i--;
                    }
                }
                
                cell = _cells[i];
                
                if(!cell.viewController.collapsed && cell.viewController.stringOccurrencesCount > 0) {
                    _stringOccurrenceMarkedResultIndex = forward? 0 : cell.viewController.stringOccurrencesCount-1;
                    _stringOccurrenceMarkedCellIndex = i;
                    
                    [cell.viewController markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
                    
                    break;
                }
            }
        }
        
        markedCell = cell;
    }
    
    // if there is a marked occurrence, make sure it is visible
    // just scroll the thread view to the right cell
    // note that the cell itself will scroll the html text to the marked position
    if(_stringOccurrenceMarked) {
        NSAssert(markedCell != nil, @"no cell");
        
        NSRect visibleRect = [[_messageThreadView contentView] documentVisibleRect];
        
        if(markedCell.viewController.view.frame.origin.y < visibleRect.origin.y || markedCell.viewController.view.frame.origin.y + markedCell.viewController.view.frame.size.height >= visibleRect.origin.y + visibleRect.size.height) {
            NSPoint cellPosition = NSMakePoint(_messageThreadView.visibleRect.origin.x, markedCell.viewController.view.frame.origin.y);
            [[_messageThreadView documentView] scrollPoint:cellPosition];
        }
    }
    
    _findContentsActive = YES;
}

- (void)removeFindContentsResults {
    NSAssert(_currentMessageThread != nil, @"_currentMessageThread == nil");
    NSAssert(_cells.count > 0, @"no cells");
    
    for(SMMessageThreadCell *cell in _cells)
        [cell.viewController removeAllHighlightedOccurrencesOfString];
    
    [self clearStringOccurrenceMarkIndex];
    
    _currentStringToFind = nil;
    _currentStringToFindMatchCase = NO;
    _findContentsActive = NO;
}

- (void)clearStringOccurrenceMarkIndex {
    _stringOccurrenceMarked = NO;
    _stringOccurrenceMarkedCellIndex = 0;
    _stringOccurrenceMarkedResultIndex = 0;
}

- (void)keyDown:(NSEvent *)theEvent {
    if([theEvent keyCode] == 53) { // esc
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[appDelegate appController] hideFindContentsPanel];
    } else {
        [super keyDown:theEvent];
    }
}

- (NSUInteger)findCell:(SMMessageThreadCellViewController*)cellViewControllerToReply {
    NSUInteger cellIdx = 0;
    for(; cellIdx < _cells.count; cellIdx++) {
        SMMessageThreadCell *cell = _cells[cellIdx];
        
        if(cell.viewController == cellViewControllerToReply) {
            break;
        }
    }
    
    NSAssert(cellIdx <= _cells.count, @"bad cell idx %lu", cellIdx);
    
    return cellIdx;
}

#pragma mark Message manipulations

- (void)deleteMessage:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to delete not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    id<SMMailbox> mailbox = appDelegate.currentMailbox;
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    SMMessageListViewController *messageListViewController = [[appDelegate appController] messageListViewController];
    NSAssert(messageListViewController != nil, @"messageListViewController is nil");
    
    if(_currentMessageThread.messagesCount == 1) {
        [messageListViewController moveSelectedMessageThreadsToFolder:trashFolder.fullName];
    }
    else {
        NSAssert(_currentMessageThread.messagesCount > 1, @"no messages in the current message thread");
        
        SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
        SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
        NSAssert(currentFolder != nil, @"no current folder");
        
        if([currentFolder moveMessage:cell.message.uid threadId:_currentMessageThread.threadId toRemoteFolder:trashFolder.fullName]) {
            [messageListViewController reloadMessageList:YES];
        }
        
        [self updateMessageThread];
    }
}

- (void)changeMessageCellUnreadFlag:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to change unread flag not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");
    
    [currentFolder setMessageUnseen:cell.message unseen:!cell.message.unseen];
    [_currentMessageThread updateThreadAttributesFromMessageUID:cell.message.uid];
    
    // If the message is being marked unseen, collapse its cell.
    // Then update the message thread and the message list views to reflect that.
    Boolean preserveMessageListSelection = YES;
    
    if(cell.message.unseen) {
        if(_cells.count == 1) {
            [self setMessageThread:nil selectedThreadsCount:0]; // TODO: why clear the message thread?
            
            preserveMessageListSelection = NO;
        }
        else {
            cell.viewController.collapsed = YES;
            
            [self updateMessageThread];
            [self updateCellFrames];
        }
    }
    else {
        [self updateMessageThread];
    }
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:preserveMessageListSelection];
}

- (void)changeMessageCellFlaggedFlag:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to change flagged flag not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];
    SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");
    
    [currentFolder setMessageFlagged:cell.message flagged:(cell.message.flagged? NO : YES)];
    [_currentMessageThread updateThreadAttributesFromMessageUID:cell.message.uid];
    
    [self updateMessageThread];
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark Saving downloads

- (void)saveAttachments:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to save downloads not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    [cell.viewController saveAttachments];
}

- (void)saveAttachmentsToDownloads:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to save downloads not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    [cell.viewController saveAttachmentsToDownloads];
}

#pragma mark Message reply composition

- (void)composeMessageReply:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageThreadCellViewController *cellViewControllerToReply = [messageInfo objectForKey:@"ThreadCell"];
    
    NSUInteger cellIdx = 0;
    if(cellViewControllerToReply != nil) {
        cellIdx = [self findCell:cellViewControllerToReply];
        
        if(cellIdx == _cells.count) {
            SM_LOG_DEBUG(@"cell to reply not found");
            return;
        }
    }
    
    [self closeEmbeddedEditor:YES]; // Close the currently edited message; it should save draft, etc.
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    
    _cellViewControllerToReply = cell.viewController;
    
    Boolean plainText = NO; // TODO: detect if the message being replied is plain text, see issue #88
    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:NSMakeRect(0, 0, 200, 100) embedded:YES draftUid:0 plainText:plainText];
    
    NSView *editorSubview = _messageEditorViewController.view;
    NSAssert(editorSubview != nil, @"_messageEditorViewController.view is nil");
    
    NSMutableArray *toAddressList = nil;
    NSMutableArray *ccAddressList = nil;
    
    NSAssert(cell.message.subject != nil, @"bad message subject");
    NSString *replySubject = cell.message.subject;
    
    Boolean reply = NO;
    NSString *replyKind = [messageInfo objectForKey:@"ReplyKind"];
    if([replyKind isEqualToString:@"Forward"]) {
        if(![SMStringUtils string:replySubject hasPrefix:@"Fw: " caseInsensitive:YES]) {
            replySubject = [NSString stringWithFormat:@"Fw: %@", replySubject];
        }
    }
    else {
        BOOL toAddressIsSet = NO;
        
        if([replyKind isEqualToString:@"Reply"]) {
            toAddressList = [NSMutableArray array];
            
            reply = YES;
            
            SMAddress *toAddress = [messageInfo objectForKey:@"ToAddress"];
            if(toAddress != nil) {
                [toAddressList addObject:[toAddress mcoAddress]];
                
                toAddressIsSet = YES;
            }
        }
        else if([replyKind isEqualToString:@"ReplyAll"]) {
            toAddressList = [NSMutableArray arrayWithArray:cell.message.toAddressList];
            ccAddressList = [NSMutableArray arrayWithArray:cell.message.ccAddressList];
            
            reply = YES;
        }
        
        // TODO: remove ourselves (myself) from CC and TO
        
        if(!toAddressIsSet) {
            MCOAddress *fromAddress = [cell.message fromAddress];
            NSAssert(fromAddress != nil, @"bad message from address");
            
            [toAddressList addObject:fromAddress];
        }
        
        if(reply) {
            if(![SMStringUtils string:replySubject hasPrefix:@"Re: " caseInsensitive:YES]) {
                replySubject = [NSString stringWithFormat:@"Re: %@", replySubject];
            }
        }
    }
    
    if(cell.message.htmlBodyRendering != nil) {
        [_messageEditorViewController startEditorWithHTML:cell.message.htmlBodyRendering subject:replySubject to:toAddressList cc:ccAddressList bcc:nil kind:kFoldedReplyEditorContentsKind mcoAttachments:(reply? nil : cell.message.attachments)];
        
        editorSubview.translatesAutoresizingMaskIntoConstraints = YES;
        editorSubview.autoresizingMask = NSViewWidthSizable;
        
        [_contentView addSubview:editorSubview];
        
        [self updateCellFrames];
    }
    else {
        SM_LOG_WARNING(@"Message body is not yet loaded");
    }
}

- (void)deleteEditedMessageDraft:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageEditorViewController *messageEditorViewController = [messageInfo objectForKey:@"MessageEditorViewController"];
    
    if(_messageEditorViewController != nil && _messageEditorViewController == messageEditorViewController) {
        [self closeEmbeddedEditor:NO];
        [self updateCellFrames];
    }
}

- (void)messageSent:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageEditorViewController *messageEditorViewController = [messageInfo objectForKey:@"MessageEditorViewController"];
    
    if(_messageEditorViewController != nil && _messageEditorViewController == messageEditorViewController) {
        [self closeEmbeddedEditor:NO];
        [self updateCellFrames];
    }
}

- (void)messageEditorContentHeightChanged:(NSNotification *)notification {
    if(_messageEditorViewController != nil) {
        [self updateCellFrames];
    }
}

- (void)messageThreadCellHeightChanged:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageThreadCellViewController *cellViewControllerToReply = [messageInfo objectForKey:@"ThreadCell"];
    
    if(cellViewControllerToReply != nil) {
        if([self findCell:cellViewControllerToReply] != _cells.count) {
            [self updateCellFrames];
        }
    }
}

@end
