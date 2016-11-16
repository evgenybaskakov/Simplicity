//
//  SMMessageThreadViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/2/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMNotificationsController.h"
#import "SMFindContentsPanelViewController.h"
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
#import "SMMessageThreadAccountProxy.h"
#import "SMAbstractLocalFolder.h"
#import "SMMessageStorage.h"
#import "SMMailbox.h"
#import "SMMessageWindowController.h"
#import "SMMessageEditorViewController.h"
#import "SMHTMLMessageEditorView.h"
#import "SMAddressFieldViewController.h"
#import "SMTokenField.h"
#import "SMFlippedView.h"
#import "SMBoxView.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMStringUtils.h"
#import "SMAddress.h"

static const CGFloat MIN_EDITOR_HEIGHT = 200;
static const CGFloat MAX_EDITOR_HEIGHT = 600;
static const CGFloat CELL_SPACING = 0;
static const CGFloat NEXT_CELL_SCROLL_THRESHOLD = 20;

@interface SMMessageThreadViewController()
- (void)messageBodyFetched:(NSNotification *)notification;
- (void)updateMessageView:(uint64_t)messageId threadId:(uint64_t)threadId;
@end

@implementation SMMessageThreadViewController {
    NSScrollView *_messageThreadView;
    SMMessagePlaceholderViewController *_messagePlaceHolderViewController;
    SMMessageThreadInfoViewController *_messageThreadInfoViewController;
    SMMessageEditorViewController *_messageEditorViewController;
    SMMessageThreadCellViewController *_cellViewControllerToReply;
    SMFindContentsPanelViewController *_findContentsPanelViewController;
    NSMutableArray<SMMessageThreadCell*> *_cells;
    NSView *_contentView;
    BOOL _findContentsActive;
    NSString *_currentStringToFind;
    BOOL _currentStringToFindMatchCase;
    BOOL _stringOccurrenceMarked;
    NSUInteger _stringOccurrenceMarkedCellIndex;
    NSUInteger _stringOccurrenceMarkedResultIndex;
    NSUInteger _firstVisibleCell, _lastVisibleCell;
    BOOL _cellsArranged;
    BOOL _cellsUpdateStarted;
    BOOL _findContentsPanelShown;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteMessage:) name:@"DeleteMessage" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMessageCellUnreadFlag:) name:@"ChangeMessageUnreadFlag" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeMessageCellFlaggedFlag:) name:@"ChangeMessageFlaggedFlag" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discardMessageDraft:) name:@"DiscardMessageDraft" object:nil];
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

- (SMMessageThreadCellViewController*)createMessageThreadCell:(SMMessage*)message collapsed:(BOOL)collapsed {
    SMMessageThreadCellViewController *messageThreadCellViewController = [[SMMessageThreadCellViewController alloc] init:self collapsed:collapsed];
    
    [messageThreadCellViewController setMessage:message];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [appDelegate.currentAccount messageListController];

    if([messageThreadCellViewController loadMessageBody]) {
        [messageListController fetchMessageInlineAttachments:message messageThread:_currentMessageThread];
    }
    else {
        [messageListController fetchMessageBodyUrgentlyWithUID:message.uid messageId:message.messageId messageDate:message.date remoteFolder:[message remoteFolder] messageThread:_currentMessageThread];
    }
    
    return messageThreadCellViewController;
}

- (void)removeEmbeddedEditor {
    [_messageEditorViewController.view removeFromSuperview];
    
    _messageEditorViewController = nil;
    _cellViewControllerToReply = nil;
}

- (void)closeEmbeddedEditor:(BOOL)saveDraft {
    if(_messageEditorViewController != nil) {
        // TODO: it looks like that's not enough (unreg token notifi. as well)
        
        [_messageEditorViewController closeEditor:saveDraft askConfirmationIfNecessary:NO];

        [self removeEmbeddedEditor];
    }
}

- (void)setMessageThread:(SMMessageThread*)messageThread selectedThreadsCount:(NSUInteger)selectedThreadsCount localFolder:(id<SMAbstractLocalFolder>)localFolder {
    if(messageThread == nil) {
        [self hideCurrentMessageThread:selectedThreadsCount];
    }

    if(_currentMessageThread == messageThread) {
        // Note that the local folder may be different (e.g. an account folder vs a unified folder)
        return;
    }
    
    [self closeEmbeddedEditor:YES];
    
    _currentLocalFolder = localFolder;
    _currentMessageThread = messageThread;

    if(_currentMessageThread != nil) {
        [self showCurrentMessageThread];
    }

    if(_messageThreadInfoViewController == nil) {
        _messageThreadInfoViewController = [[SMMessageThreadInfoViewController alloc] init];
        _messageThreadInfoViewController.messageThreadViewController = self;
        
        NSView *infoView = [_messageThreadInfoViewController view];
        NSAssert(infoView != nil, @"no info view");
        
        infoView.translatesAutoresizingMaskIntoConstraints = YES;
    }
    
    [_messageThreadInfoViewController setMessageThread:_currentMessageThread];
    
    [_cells removeAllObjects];
    
    _contentView = [[SMFlippedView alloc] initWithFrame:_messageThreadView.frame];
    _contentView.translatesAutoresizingMaskIntoConstraints = YES;
    _contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
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
            BOOL collapsed = (messages.count == 1? NO : (_currentMessageThread.unseen? i != lastUnseenMessageIdx : i > 0));
            SMMessageThreadCellViewController *viewController = [self createMessageThreadCell:messages[i] collapsed:collapsed];
            
            [viewController enableCollapse:(messages.count > 1)];
            viewController.shouldDrawBottomLineWhenCollapsed = (i != messages.count-1? NO : YES);
            viewController.shouldDrawBottomLineWhenUncollapsed = (i != messages.count-1? YES : NO);
            viewController.cellIndex = i;
            
            [_contentView addSubview:[viewController view]];
            
            _cells[i] = [[SMMessageThreadCell alloc] initWithMessage:messages[i] viewController:viewController];
        }
        
        [self updateCellFrames];
        
        if(lastUnseenMessageIdx != NSUIntegerMax) {
            SMMessageThreadCell *cell = _cells[lastUnseenMessageIdx];

            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate.messageThreadAccountProxy setMessageUnseen:_currentMessageThread message:cell.message unseen:NO];

            [_currentMessageThread updateThreadAttributesForMessageId:cell.message.messageId];
            
            [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
        }
    }
    else {
        [_messageThreadInfoViewController.view removeFromSuperview];
    }
    
    // on every message thread switch, we hide the find contents panel
    // because it is presumably needed only when the user means to search the particular message thread
    [self hideFindContentsPanel];

    [self updateNavigationControls];

    // reflect the local folder properties to the view of the message thread
    if(_currentLocalFolder.kind == SMFolderKindOutbox) {
        _messageThreadInfoViewController.addLabelButtonEnabled = NO;
    }
    else {
        _messageThreadInfoViewController.addLabelButtonEnabled = YES;
    }
}

- (void)showCurrentMessageThread {
    NSView *rootView = self.view;
    
    [_messagePlaceHolderViewController.view removeFromSuperview];

    [rootView addSubview:_messageThreadView];

    _messageThreadView.frame = NSMakeRect(0, 0, rootView.frame.size.width, rootView.frame.size.height);
}

- (void)hideCurrentMessageThread:(NSUInteger)selectedThreadsCount {
    NSView *rootView = self.view;

    [_messageThreadView removeFromSuperview];

    _messagePlaceHolderViewController.selectedMessagesLabel.stringValue = (selectedThreadsCount == 0? @"No messages selected" : [NSString stringWithFormat:@"%lu messages selected", selectedThreadsCount]);
    
    [rootView addSubview:_messagePlaceHolderViewController.view];

    _messagePlaceHolderViewController.view.frame = NSMakeRect(0, 0, rootView.frame.size.width, rootView.frame.size.height);
}

#pragma mark Building visual layout of message threads

- (void)updateMessageThread {
    if(_currentMessageThread == nil)
        return;
    
    NSAssert(_cells != nil, @"no cells in the current thread");
    
    NSArray *newMessages = [_currentMessageThread messagesSortedByDate];
    if([_currentMessageThread.messageStorage messageThreadById:_currentMessageThread.threadId] != nil && newMessages.count > 0) {
        // check whether messages did not change
        if(newMessages.count == _cells.count) {
            BOOL equal = YES;
            
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
                
                [_messageThreadInfoViewController updateMessageThread];
                
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

        [self hideCurrentMessageThread:0];
    }

    [self updateNavigationControls];
}

- (void)updateNavigationControls {
    // Update the navigation buttons
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(_currentMessageThread == nil || _cells.count == 1) {
        [[appDelegate appController] disableMessageThreadNavigationControl];
    }
    else {
        [[appDelegate appController] enableMessageThreadNavigationControl];
    }
}

- (BOOL)shouldUseFullHeightForFirstCell {
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
    
    const CGFloat infoViewHeight = [SMMessageThreadInfoViewController infoHeaderHeight];
    
    if([self shouldUseFullHeightForFirstCell]) {
        fullHeight += _contentView.frame.size.height;
    }
    else {
        fullHeight += infoViewHeight;
        
        for(NSInteger i = 0; i < _cells.count; i++) {
            SMMessageThreadCell *cell = _cells[i];
            fullHeight += (CGFloat)cell.viewController.cellHeight;
            
            if(i + 1 < _cells.count) {
                fullHeight += CELL_SPACING;
            }
        }
    }
    
    _contentView.frame = NSMakeRect(0, 0, _contentView.frame.size.width, fullHeight + _topOffset);
    _contentView.autoresizingMask = NSViewWidthSizable;
    
    if([self shouldUseFullHeightForFirstCell]) {
        _contentView.autoresizingMask |= NSViewHeightSizable;
    }
    
    NSView *infoView = [_messageThreadInfoViewController view];
    NSAssert(infoView != nil, @"no info view");
    
    infoView.frame = NSMakeRect(-1, _topOffset, _contentView.frame.size.width+2, infoViewHeight);
    infoView.autoresizingMask = NSViewWidthSizable;
    
    CGFloat ypos = _topOffset + infoViewHeight + CELL_SPACING;
    
    for(NSInteger i = 0; i < _cells.count; i++) {
        SMMessageThreadCell *cell = _cells[i];
        [cell.viewController.boxView setTag:i];
        
        SMMessageThreadViewController __weak *weakSelf = self;
        
        cell.viewController.boxView.mouseEnteredBlock = ^(SMBoxView *box) {
            SMMessageThreadViewController *_self = weakSelf;
            if(!_self) {
                return;
            }
            
            NSInteger row = box.tag;
            
            if(row + 1 < _self->_cells.count) {
                SMBoxView *nextRowBox = _self->_cells[row + 1].viewController.boxView;
                nextRowBox.drawTop = NO;
            }
        };
        
        cell.viewController.boxView.mouseExitedBlock = ^(SMBoxView *box) {
            SMMessageThreadViewController *_self = weakSelf;
            if(!_self) {
                return;
            }
            
            NSInteger row = box.tag;
            
            if(row + 1 < _self->_cells.count) {
                SMBoxView *nextRowBox = _self->_cells[row + 1].viewController.boxView;
                nextRowBox.drawTop = YES;
            }
        };
        
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

- (void)updateMessageView:(uint64_t)messageId threadId:(uint64_t)threadId {
    if(_currentMessageThread == nil || _currentMessageThread.threadId != threadId)
        return;
    
    // TODO: optimize search?
    for(NSInteger i = 0; i < _cells.count; i++) {
        SMMessageThreadCell *cell = _cells[i];
        SMMessage *message = cell.message;
        
        if(message.messageId == messageId) {
            [[_currentMessageThread.account messageListController] fetchMessageInlineAttachments:message messageThread:_currentMessageThread];
            
            [cell.viewController updateMessage];
            
            if(![cell.viewController loadMessageBody]) {
                NSAssert(FALSE, @"message id %llu (thread id %lld) fetched with no body!!!", messageId, threadId);
            }
            
            return;
        }
    }
    
    SM_LOG_DEBUG(@"message id %llu doesn't belong to thread id %lld", messageId, threadId);
}

#pragma mark Cells collapsing / uncollapsing

- (void)setCellCollapsed:(BOOL)collapsed cellIndex:(NSUInteger)cellIndex {
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
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate.messageThreadAccountProxy setMessageUnseen:_currentMessageThread message:cell.message unseen:NO];
        
        [_currentMessageThread updateThreadAttributesForMessageId:cell.message.messageId];
        
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

#pragma mark Scroll to message cells

- (void)animatedScrollTo:(CGFloat)ypos {
    NSRect cellRect = NSMakeRect(_messageThreadView.visibleRect.origin.x, ypos, _messageThreadView.visibleRect.size.width, _messageThreadView.visibleRect.size.height);
    
    NSClipView *clipView = [_messageThreadView contentView];
    NSRect constrainedRect = [clipView constrainBoundsRect:cellRect];
    [NSAnimationContext beginGrouping];
    [[clipView animator] setBoundsOrigin:constrainedRect.origin];
    [NSAnimationContext endGrouping];
    
    [_messageThreadView reflectScrolledClipView:clipView];
}

- (void)scrollToPrevMessage {
    SMMessageThreadCell *cell = _cells[_firstVisibleCell];
    CGFloat ypos = (CGFloat)cell.viewController.view.frame.origin.y;

    if(_firstVisibleCell > 0) {
        CGFloat curYPos = _messageThreadView.documentVisibleRect.origin.y + _topOffset;
        
        if(fabs(curYPos - ypos) < NEXT_CELL_SCROLL_THRESHOLD) {
            if(_firstVisibleCell == 1) {
                ypos = _topOffset - 1;
            }
            else {
                SMMessageThreadCell *prevCell = _cells[_firstVisibleCell-1];
                ypos = (CGFloat)prevCell.viewController.view.frame.origin.y;
            }
        }
    }
    else {
        ypos = _topOffset - 1;
    }

    [self animatedScrollTo:ypos - _topOffset + 1];
}

- (void)scrollToNextMessage {
    if(_firstVisibleCell + 1 < _cells.count) {
        CGFloat curYPos = _messageThreadView.documentVisibleRect.origin.y + _topOffset;

        SMMessageThreadCell *nextCell = _cells[_firstVisibleCell + 1];
        CGFloat ypos = (CGFloat)nextCell.viewController.view.frame.origin.y;
        
        if(curYPos < ypos && ypos - curYPos < NEXT_CELL_SCROLL_THRESHOLD && _firstVisibleCell + 2 < _cells.count) {
            SMMessageThreadCell *prevCell = _cells[_firstVisibleCell + 2];
            ypos = (CGFloat)prevCell.viewController.view.frame.origin.y;
        }
        
        [self animatedScrollTo:ypos - _topOffset + 1];
    }
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
        
        [_contentView addSubview:_cells[0].viewController.view];
    }
    
    NSAssert(_firstVisibleCell <= _lastVisibleCell, @"bad _firstVisibleCell %lu, _lastVisibleCell %lu", _firstVisibleCell, _lastVisibleCell);
    NSAssert(_lastVisibleCell < _cells.count, @"bad _lastVisibleCell %lu, _cells.count %lu", _lastVisibleCell, _cells.count);
    
    NSRect visibleRect = [[_messageThreadView contentView] documentVisibleRect];
    
    const NSUInteger oldFirstVisibleCell = _firstVisibleCell;
    const NSUInteger oldLastVisibleCell = _lastVisibleCell;
    
    SMMessageThreadCell *firstCell = _cells[_firstVisibleCell];
    
    while(_firstVisibleCell > 0 && firstCell.viewController.view.frame.origin.y > visibleRect.origin.y + _topOffset) {
        firstCell = _cells[--_firstVisibleCell];
    }
    
    while(_firstVisibleCell + 1 < _cells.count && firstCell.viewController.view.frame.origin.y + firstCell.viewController.cellHeight <= visibleRect.origin.y + _topOffset) {
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
                [cell.viewController.view setFrameSize:NSMakeSize(_contentView.frame.size.width+2, _contentView.frame.size.height - _topOffset)];
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
    uint64_t messageId;
    int64_t threadId;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchedParams:notification localFolder:nil messageId:&messageId threadId:&threadId account:&account];
    
    if(_currentMessageThread.account == account) {
        [self updateMessageView:messageId threadId:threadId];
    }
}

- (void)messageViewFrameLoaded:(NSNotification *)notification {
    uint64_t messageId;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageViewFrameLoadedParams:notification messageId:&messageId account:&account];
    
    if(account == _currentMessageThread.account) {
        // TODO: optimize by adding a NSUndexSet with uids
        for(NSInteger i = 0; i < _cells.count; i++) {
            SMMessageThreadCell *cell = _cells[i];
            
            // Logic: if the message whose html body is just loaded is contained in this
            // message thread, and it is uncollapsed, cell heights may need to be adjusted.
            // TODO: maybe skip real frames update, if this cell is invisible?
            if(cell.message.messageId == messageId && !cell.viewController.collapsed) {
                [self updateCellFrames];
                break;
            }
        }
    }
}

#pragma mark Finding messages contents

- (void)findContents:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward {
    NSAssert(_currentMessageThread != nil, @"_currentMessageThread == nil");
    NSAssert(_cells.count > 0, @"no cells");
    
    SMMessageThreadCell *markedCell = nil;
    NSInteger markYPos = 0;
    
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
                        
                        markYPos = [cell.viewController markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
                        
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
            markYPos = [cell.viewController markOccurrenceOfFoundString:(++_stringOccurrenceMarkedResultIndex)];
        } else if(!forward && _stringOccurrenceMarkedResultIndex > 0) {
            markYPos = [cell.viewController markOccurrenceOfFoundString:(--_stringOccurrenceMarkedResultIndex)];
        } else {
            [cell.viewController removeMarkedOccurrenceOfFoundString];
            
            BOOL wrap = NO;
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
                    
                    markYPos = [cell.viewController markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
                    
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
        CGFloat markGlobalYpos = markedCell.viewController.view.frame.origin.y + markedCell.viewController.cellHeaderHeight + markYPos;

        const NSUInteger delta = 50;
        if(markGlobalYpos < visibleRect.origin.y + _topOffset + delta || markGlobalYpos >= visibleRect.origin.y + visibleRect.size.height - delta) {
            CGFloat newYpos = markGlobalYpos - _topOffset - delta;
            [self animatedScrollTo:(newYpos >= delta ? newYpos : 0)];
        }
    }
    
    _findContentsActive = YES;
}

- (void)removeFindContentsResults {
    if(_currentMessageThread) {
        NSAssert(_cells.count > 0, @"no cells");
        
        for(SMMessageThreadCell *cell in _cells)
            [cell.viewController removeAllHighlightedOccurrencesOfString];
        
        [self clearStringOccurrenceMarkIndex];
    }
    
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
        // Only close the current message thread if this is not a separate window
        // TODO: warn if editor is open! (issue #115)
        if(![self.view.window.delegate isKindOfClass:[SMMessageWindowController class]]) {
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            [[appDelegate.appController messageListViewController] deselectCurrentMessageThread];
        }
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

    SMUserAccount *account = _currentMessageThread.account;
    id<SMMailbox> mailbox = account.mailbox;

    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    if([_currentLocalFolder moveMessage:cell.message withinMessageThread:_currentMessageThread toRemoteFolder:trashFolder.fullName]) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
    }
    
    [self updateMessageThread];
}

- (void)changeMessageCellUnreadFlag:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        SM_LOG_DEBUG(@"cell to change unread flag not found");
        return;
    }
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate.messageThreadAccountProxy setMessageUnseen:_currentMessageThread message:cell.message unseen:!cell.message.unseen];

    [_currentMessageThread updateThreadAttributesForMessageId:cell.message.messageId];
    
    // If the message is being marked unseen, collapse its cell.
    // Then update the message thread and the message list views to reflect that.
    BOOL preserveMessageListSelection = YES;
    
    if(cell.message.unseen) {
        if(_cells.count == 1) {
            [self setMessageThread:nil selectedThreadsCount:0 localFolder:nil]; // TODO: why clear the message thread?
            
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

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate.messageThreadAccountProxy setMessageFlagged:_currentMessageThread message:cell.message flagged:(cell.message.flagged? NO : YES)];
    
    [_currentMessageThread updateThreadAttributesForMessageId:cell.message.messageId];
    
    [self updateMessageThread];
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark Draft discartion

- (void)discardMessageDraft:(NSNotification *)notification {
    [self deleteMessage:notification];
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
    
    SMMessageThreadCell *cell = _cells[cellIdx];
    
    [self closeEmbeddedEditor:YES]; // Close the currently edited message; it should save draft, etc.
    
    _cellViewControllerToReply = cell.viewController;
    
    BOOL plainText = NO; // TODO: detect if the message being replied is plain text, see issue #88
    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:NSMakeRect(0, 0, 200, 100) messageThreadViewController:self draftUid:0 plainText:plainText];
    
    NSView *editorSubview = _messageEditorViewController.view;
    NSAssert(editorSubview != nil, @"_messageEditorViewController.view is nil");
    
    NSMutableArray<SMAddress*> *toAddressList = nil;
    NSMutableArray<SMAddress*> *ccAddressList = nil;
    
    NSAssert(cell.message.subject != nil, @"bad message subject");
    NSString *replySubject = cell.message.subject;
    
    SMEditorReplyKind replyKind = [[messageInfo objectForKey:@"ReplyKind"] unsignedIntegerValue];
    NSAssert(replyKind < SMEditorReplyKind_Invalid, @"invalid reply kind %lu", replyKind);

    if(replyKind == SMEditorReplyKind_Forward) {
        replySubject = [NSString stringWithFormat:@"Fw: %@", replySubject];
    }
    else {
        [SMMessageEditorViewController getReplyAddressLists:cell.message replyKind:replyKind accountAddress:_currentMessageThread.account.accountAddress to:&toAddressList cc:&ccAddressList];

        if(replyKind == SMEditorReplyKind_ReplyOne || replyKind == SMEditorReplyKind_ReplyAll) {
            if(![SMStringUtils string:replySubject hasPrefix:@"Re: " caseInsensitive:YES]) {
                replySubject = [NSString stringWithFormat:@"Re: %@", replySubject];
            }
        }
    }
    
    SMEditorContentsKind editorKind = (replyKind == SMEditorReplyKind_Forward? kFoldedForwardEditorContentsKind : kFoldedReplyEditorContentsKind);
    
    [_messageEditorViewController startEditorWithHTML:cell.message.htmlBodyRendering subject:replySubject to:toAddressList cc:ccAddressList bcc:nil kind:editorKind mcoAttachments:(replyKind == SMEditorReplyKind_Forward? cell.message.attachments : nil)];
    
    editorSubview.translatesAutoresizingMaskIntoConstraints = YES;
    editorSubview.autoresizingMask = NSViewWidthSizable;
    
    [_contentView addSubview:editorSubview];
    
    [_messageEditorViewController setResponders:YES focusKind:[SMHTMLMessageEditorView contentKindToFocusKind:editorKind]];
    
    [self updateCellFrames];
}

- (void)closeEmbeddedEditorWithoutSavingDraft {
    [self closeEmbeddedEditor:NO];
    [self updateCellFrames];
}

- (void)deleteEditedMessageDraft:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageEditorViewController *messageEditorViewController = [messageInfo objectForKey:@"MessageEditorViewController"];
    
    if(_messageEditorViewController != nil && _messageEditorViewController == messageEditorViewController) {
        [self closeEmbeddedEditorWithoutSavingDraft];
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

#pragma mark Find Contents panel management

- (void)showFindContentsPanel:(BOOL)replace {
    if(_currentMessageThread == nil)
        return;
    
    if(_findContentsPanelViewController == nil) {
        _findContentsPanelViewController = [[SMFindContentsPanelViewController alloc] initWithNibName:@"SMFindContentsPanelViewController" bundle:nil];
        _findContentsPanelViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        _findContentsPanelViewController.view.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
        _findContentsPanelViewController.messageThreadViewController = self;
    }
  
    if(!_findContentsPanelShown) {
        NSView *rootView = self.view;

        [rootView addSubview:_findContentsPanelViewController.view];

        _findContentsPanelViewController.view.frame = NSMakeRect(0, rootView.frame.size.height - _topOffset - _findContentsPanelViewController.view.frame.size.height, rootView.frame.size.width, _findContentsPanelViewController.view.frame.size.height);
        
        _topOffset += _findContentsPanelViewController.view.frame.size.height;
        
        _findContentsPanelShown = YES;
    }
    
    NSSearchField *searchField = _findContentsPanelViewController.searchField;
    NSAssert(searchField != nil, @"searchField == nil");
    
    [[searchField window] makeFirstResponder:searchField];

    [self updateCellFrames];
}

- (void)hideFindContentsPanel {
    if(!_findContentsPanelShown)
        return;

    [self removeFindContentsResults];

    NSAssert(_findContentsPanelViewController != nil, @"_findContentsPanelViewController == nil");

    [_findContentsPanelViewController.view removeFromSuperview];

    _topOffset -= _findContentsPanelViewController.view.frame.size.height;
    
    _findContentsPanelShown = NO;
    
    [self updateCellFrames];
}

#pragma mark label manupilations

- (void)addLabel:(NSString*)label {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate.messageThreadAccountProxy addMessageThreadLabel:_currentMessageThread label:label];
    
    [_messageThreadInfoViewController updateMessageThread];
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)removeLabel:(NSString*)label {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([appDelegate.messageThreadAccountProxy removeMessageThreadLabel:_currentMessageThread label:label]) {
        [self setMessageThread:nil selectedThreadsCount:0 localFolder:nil];
        // TODO: how about open windows with this thread open?
    }
    else {
        [_messageThreadInfoViewController updateMessageThread];
    }
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark windowise editor

- (void)makeEditorWindow:(SMMessageEditorViewController *)messageEditorViewController {
    NSAssert(_messageEditorViewController == messageEditorViewController, @"unknown provided editor to windowise");
    
    [self removeEmbeddedEditor];
    [self updateCellFrames];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate appController] openMessageEditorWindow:messageEditorViewController];
}

@end
