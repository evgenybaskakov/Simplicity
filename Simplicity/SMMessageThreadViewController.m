
//
//  SMMessageThreadViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/2/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadCell.h"
#import "SMMessageThreadCellViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadInfoViewController.h"
#import "SMMessageBodyViewController.h"
#import "SMMessageListController.h"
#import "SMLocalFolder.h"
#import "SMMailbox.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWebView.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMTokenField.h"
#import "SMFlippedView.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"

static const CGFloat MIN_EDITOR_HEIGHT = 100;
static const CGFloat MAX_EDITOR_HEIGHT = 500;
static const CGFloat CELL_SPACING = -1;

@interface SMMessageThreadViewController()
- (void)messageBodyFetched:(NSNotification *)notification;
- (void)updateMessageView:(uint32_t)uid threadId:(uint64_t)threadId;
@end

@implementation SMMessageThreadViewController {
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
		NSScrollView *messageThreadView = [[NSScrollView alloc] init];
		
		[messageThreadView setBorderType:NSNoBorder];
		[messageThreadView setHasVerticalScroller:YES];
		[messageThreadView setHasHorizontalScroller:NO];
		[messageThreadView setTranslatesAutoresizingMaskIntoConstraints:NO];

		[self setView:messageThreadView];

		_cells = [NSMutableArray new];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyFetched:) name:@"MessageBodyFetched" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyLoaded:) name:@"MessageBodyLoaded" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(composeMessageReply:) name:@"ComposeMessageReply" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteMessageReply:) name:@"DeleteMessageReply" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteMessage:) name:@"DeleteMessage" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageEditorContentHeightChanged:) name:@"MessageEditorContentHeightChanged" object:nil];
    }
	
	return self;
}

#pragma mark Setting new message threads

- (SMMessageThreadCellViewController*)createMessageThreadCell:(SMMessage*)message collapsed:(Boolean)collapsed {
	SMMessageThreadCellViewController *messageThreadCellViewController = [[SMMessageThreadCellViewController alloc] initCollapsed:collapsed];
	
	[messageThreadCellViewController setMessage:message];
	
	if([messageThreadCellViewController loadMessageBody]) {
		[message fetchInlineAttachments];
	} else {
		SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
		SMMessageListController *messageListController = [[appDelegate model] messageListController];

		[messageListController fetchMessageBodyUrgently:[message uid] remoteFolder:[message remoteFolder] threadId:[_currentMessageThread threadId]];
	}
	
	return messageThreadCellViewController;
}

- (void)closeEmbeddedEditor {
    if(_messageEditorViewController != nil) {
        // TODO: save draft, etc.
        // TODO: it looks like that's not enough (unreg token notifi. as well)
        
        [_messageEditorViewController.view removeFromSuperview];
        [_messageEditorViewController closeEditor];
        
        _messageEditorViewController = nil;
        _cellViewControllerToReply = nil;
    }
}

- (void)setMessageThread:(SMMessageThread*)messageThread {
	if(_currentMessageThread == messageThread)
		return;
    
    [self closeEmbeddedEditor];

	_currentMessageThread = messageThread;

	if(_messageThreadInfoViewController == nil) {
		_messageThreadInfoViewController = [[SMMessageThreadInfoViewController alloc] init];

		NSView *infoView = [_messageThreadInfoViewController view];
		NSAssert(infoView != nil, @"no info view");
		
		infoView.translatesAutoresizingMaskIntoConstraints = YES;
	}

	[_messageThreadInfoViewController setMessageThread:_currentMessageThread];

	[_cells removeAllObjects];

	NSScrollView *messageThreadView = (NSScrollView*)[self view];

	_contentView = [[SMFlippedView alloc] initWithFrame:[messageThreadView frame]];
	_contentView.translatesAutoresizingMaskIntoConstraints = YES;
	
	[messageThreadView setDocumentView:_contentView];
	
	[[messageThreadView contentView] setPostsBoundsChangedNotifications:YES];
	[[messageThreadView contentView] setPostsFrameChangedNotifications:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[messageThreadView contentView]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:[messageThreadView contentView]];

	[_contentView addSubview:[_messageThreadInfoViewController view]];

	if(_currentMessageThread != nil) {
		NSAssert(_currentMessageThread.messagesCount > 0, @"no messages in message thread");
	
		NSArray *messages = [_currentMessageThread messagesSortedByDate];

		_cells = [NSMutableArray arrayWithCapacity:messages.count];

		NSUInteger lastUnseenMessageIdx = 0;
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
			viewController.cellIndex = i;

			[_contentView addSubview:[viewController view]];

			_cells[i] = [[SMMessageThreadCell alloc] initWithMessage:messages[i] viewController:viewController];
		}

		[self updateCellFrames];
	}
	
	// on every message thread switch, we hide the find contents panel
	// because it is presumably needed only when the user means to search the particular message thread
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[appDelegate appController] hideFindContentsPanel];
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
		
		//NSLog(@"%s: message thread id %llu has been updated (old message count %lu, new %ld)", __func__, _currentMessageThread.threadId, _cells.count, _currentMessageThread.messagesCount);
		
		// remove old (vanished) messages
		for(NSInteger t = _cells.count; t > 0; t--) {
			NSInteger i = t-1;
			SMMessageThreadCell *cell = _cells[i];
			
			// TODO: use the sorting info for fast search
			if(![newMessages containsObject:cell.message]) {
                if(_cellViewControllerToReply == cell.viewController) {
                    NSAssert(nil, @"%s:%d: TODO: remove the currently composed reply????", __func__, __LINE__);
                }

				[cell.viewController.view removeFromSuperview];
				[_cells removeObjectAtIndex:i];

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
		//NSLog(@"%s: message thread id %llu is empty", __func__, _currentMessageThread.threadId);

		[_cells removeAllObjects];
		[_contentView setSubviews:[NSArray array]];

		_currentMessageThread = nil;

		[_messageThreadInfoViewController setMessageThread:nil];
	}
}

- (void)updateCellFrames {
	_cellsUpdateStarted = YES;

	NSAssert(_cells.count > 0, @"no cells");

	CGFloat fullHeight = 0;
    CGFloat editorHeight = 0;
    
    if(_messageEditorViewController != nil) {
        editorHeight = MAX(MIN_EDITOR_HEIGHT, MIN(_messageEditorViewController.editorFullHeight, MAX_EDITOR_HEIGHT));
        
        fullHeight += editorHeight;
        fullHeight += CELL_SPACING;
    }

	if(_cells.count > 1 || _messageEditorViewController != nil) {
		fullHeight += [SMMessageThreadInfoViewController infoHeaderHeight];
		
		for(NSInteger i = 0; i < _cells.count; i++) {
			SMMessageThreadCell *cell = _cells[i];
			fullHeight += (CGFloat)cell.viewController.cellHeight;
			
			if(i + 1 < _cells.count)
				fullHeight += CELL_SPACING;
		}
	} else {
		fullHeight += _contentView.frame.size.height;
	}

	_contentView.frame = NSMakeRect(0, 0, _contentView.frame.size.width, fullHeight);
	_contentView.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;

    if(_cells.count == 1 && _messageEditorViewController == nil) {
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
        if(cell.viewController == _cellViewControllerToReply) {
            if(i == 0) {
                // Avoid negative overlapping between the editor, because its frame
                // is already borderless.
                ypos -= CELL_SPACING;
            }

            NSView *editorSubview = _messageEditorViewController.view;
            
            // Note that the editor width doesn't have to exceed the content view width,
            // because it already does.
            editorSubview.frame = NSMakeRect(0, ypos, infoView.frame.size.width, editorHeight);
            ypos += editorHeight + CELL_SPACING;
        }

		NSView *subview = cell.viewController.view;
        subview.translatesAutoresizingMaskIntoConstraints = YES;

		if(_cells.count == 1 && _messageEditorViewController == nil) {
			subview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
			subview.frame = NSMakeRect(-1, ypos, infoView.frame.size.width+2, fullHeight);
		} else {
			subview.autoresizingMask = NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
			subview.frame = NSMakeRect(-1, ypos, infoView.frame.size.width+2, cell.viewController.cellHeight);
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
			[message fetchInlineAttachments];

			[cell.viewController updateMessage];

			if(![cell.viewController loadMessageBody]) {
				NSAssert(FALSE, @"message uid %u (thread id %lld) fetched with no body!!!", uid, threadId);
			}
			
			return;
		}
	}
	
	NSLog(@"%s: message uid %u doesn't belong to thread id %lld", __func__, uid, threadId);
}

#pragma mark Cells collapsing / uncollapsing

- (void)setCellCollapsed:(Boolean)collapsed cellIndex:(NSUInteger)cellIndex {
	NSAssert(cellIndex < _cells.count, @"bad index %lu", cellIndex);
	
	if(_findContentsActive) {
		SMMessageThreadCell *cell = _cells[cellIndex];

		if(collapsed) {
			[cell.viewController removeAllHighlightedOccurrencesOfString];
			
			if(_stringOccurrenceMarked && _stringOccurrenceMarkedCellIndex == cellIndex)
				[self clearStringOccurrenceMarkIndex];
		} else {
			[cell.viewController highlightAllOccurrencesOfString:_currentStringToFind matchCase:_currentStringToFindMatchCase];
		}
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
	
	NSScrollView *messageThreadView = (NSScrollView*)[self view];
	NSRect visibleRect = [[messageThreadView contentView] documentVisibleRect];
	
	const NSUInteger oldFirstVisibleCell = _firstVisibleCell;
	const NSUInteger oldLastVisibleCell = _lastVisibleCell;
	
	SMMessageThreadCell *firstCell = _cells[_firstVisibleCell];

	while(_firstVisibleCell > 0 && firstCell.viewController.view.frame.origin.y > visibleRect.origin.y) {
		firstCell = _cells[--_firstVisibleCell];
	}

	while(_firstVisibleCell + 1 < _cells.count && firstCell.viewController.view.frame.origin.y + firstCell.viewController.cellHeight <= visibleRect.origin.y) {
//TODO: should we?
//		if(!firstCell.viewController.collapsed)
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
//		if(!lastCell.viewController.collapsed)
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
			if(_cells.count > 1) {
				[cell.viewController.view setFrameSize:NSMakeSize(_contentView.frame.size.width+2, cell.viewController.cellHeight)];
			}
			
			[_contentView addSubview:cell.viewController.view];
		}
	}
}

- (void)viewBoundsDidChange:(NSNotification *)notification {
//	NSClipView *changedContentView = [notification object];
//	NSLog(@"%s: %@", __func__, changedContentView);

	[self arrangeVisibleCells];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
//	NSClipView *changedContentView = [notification object];
//	NSLog(@"%s: %@", __func__, changedContentView);

	[self arrangeVisibleCells];
}

#pragma mark Processing incoming notifications

- (void)messageBodyFetched:(NSNotification *)notification {
	NSDictionary *messageInfo = [notification userInfo];
	
	[self updateMessageView:[[messageInfo objectForKey:@"UID"] unsignedIntValue] threadId:[[messageInfo objectForKey:@"ThreadId"] unsignedLongLongValue]];
}

- (void)messageBodyLoaded:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];

    uint32_t uid = [[messageInfo objectForKey:@"UID"] unsignedIntValue];

    for(NSInteger i = 0; i < _cells.count; i++) {
        SMMessageThreadCell *cell = _cells[i];
        
        // Logic: if the message whose html body is just loaded is contained in this
        // message thread, and it is uncollapsed, cell heights may need to be adjusted.
        // TODO: maybe skip real frames update, if this cell is invisible?
        if(cell.message.uid == uid && !cell.viewController.collapsed) {
            [self updateCellFrames];
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

		NSScrollView *messageThreadView = (NSScrollView*)[self view];
		NSRect visibleRect = [[messageThreadView contentView] documentVisibleRect];
		
		if(markedCell.viewController.view.frame.origin.y < visibleRect.origin.y || markedCell.viewController.view.frame.origin.y + markedCell.viewController.view.frame.size.height >= visibleRect.origin.y + visibleRect.size.height) {
			NSPoint cellPosition = NSMakePoint(messageThreadView.visibleRect.origin.x, markedCell.viewController.view.frame.origin.y);
			[[messageThreadView documentView] scrollPoint:cellPosition];
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
        NSLog(@"%s: cell to reply not found", __func__);
        return;
    }

    SMMessageThreadCell *cell = _cells[cellIdx];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
    NSAssert(currentFolder != nil, @"no current folder");

    SMMailbox *mailbox = [[appDelegate model] mailbox];
    SMFolder *trashFolder = [mailbox trashFolder];
    NSAssert(trashFolder != nil, @"no trash folder");
    
    if([currentFolder moveMessage:cell.message.uid threadId:_currentMessageThread.threadId toRemoteFolder:trashFolder.fullName]) {
        NSLog(@"%s: TODO: refresh message list! close editor!", __func__);
    }

    [self updateMessageThread];
}

#pragma mark Message reply composition

- (void)composeMessageReply:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    NSUInteger cellIdx = [self findCell:[messageInfo objectForKey:@"ThreadCell"]];
    
    if(cellIdx == _cells.count) {
        NSLog(@"%s: cell to reply not found", __func__);
        return;
    }

    [self closeEmbeddedEditor]; // Close the currently edited message; it should save draft, etc.
    
    SMMessageThreadCell *cell = _cells[cellIdx];

    _cellViewControllerToReply = cell.viewController;
    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:NSMakeRect(0, 0, 200, 100) embedded:YES];

    NSView *editorSubview = _messageEditorViewController.view;
    NSAssert(editorSubview != nil, @"_messageEditorViewController.view is nil");

    NSString *replyHtmlText = nil;
    
    NSString *replyKind = [messageInfo objectForKey:@"ReplyKind"];
    if([replyKind isEqualToString:@"Reply"]) {
        replyHtmlText = [NSString stringWithFormat:@"Compose the reply here...<br><br><br><blockquote>%@</blockquote>", [cell.message htmlBodyRendering], nil];
    }
    else if([replyKind isEqualToString:@"ReplyAll"]) {
        replyHtmlText = [NSString stringWithFormat:@"Compose the reply to all here...<br><br><br><blockquote>%@</blockquote>", [cell.message htmlBodyRendering], nil];
    }
    else if([replyKind isEqualToString:@"Forward"]) {
        replyHtmlText = [NSString stringWithFormat:@"Compose the forward here...<br><br><br><blockquote>%@</blockquote>", [cell.message htmlBodyRendering], nil];
    }
    else {
        NSAssert(false, @"Unrecognized reply kind %@", replyKind);
    }
    
    if(![replyKind isEqualToString:@"Forward"]) {
        NSString *fromAddress = [cell.message from];
        NSAssert(fromAddress != nil, @"bad message from address");

        [_messageEditorViewController.toBoxViewController.tokenField setObjectValue:fromAddress];

        if([replyKind isEqualToString:@"ReplyAll"]) {
            NSMutableArray *ccAddressList = [NSMutableArray arrayWithArray:[cell.message parsedToAddressList]];
            // TODO: remove ourselves (myself) from this CC list
            
            NSArray *parsedMessageCcAddressList = [cell.message parsedCcAddressList];
            if(parsedMessageCcAddressList != nil && parsedMessageCcAddressList.count != 0) {
                [ccAddressList addObjectsFromArray:parsedMessageCcAddressList];
            }

            [_messageEditorViewController.ccBoxViewController.tokenField setObjectValue:ccAddressList];
        }
    }

    [_messageEditorViewController.messageTextEditor startEditorWithHTML:replyHtmlText];

    editorSubview.translatesAutoresizingMaskIntoConstraints = YES;
    editorSubview.autoresizingMask = NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
    
    [_contentView addSubview:editorSubview];

    [self updateCellFrames];
}

- (void)deleteMessageReply:(NSNotification *)notification {
    NSDictionary *messageInfo = [notification userInfo];
    SMMessageEditorViewController *messageEditorViewController = [messageInfo objectForKey:@"MessageEditorViewController"];
    
    if(_messageEditorViewController != nil && _messageEditorViewController == messageEditorViewController) {
        [self closeEmbeddedEditor];
        [self updateCellFrames];
    }
}

- (void)messageEditorContentHeightChanged:(NSNotification *)notification {
    if(_messageEditorViewController != nil) {
        [self updateCellFrames];
    }
}

@end
