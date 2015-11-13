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
#import "SMImageRegistry.h"
#import "SMMessageBodyViewController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageListCellView.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMailbox.h"
#import "SMMailboxViewController.h"
#import "SMFolderColorController.h"
#import "SMMessageBookmarksView.h"
#import "SMSimplicityContainer.h"
#import "SMPreferencesController.h"
#import "SMLocalFolder.h"
#import "SMFolder.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"

@implementation SMMessageListViewController {
	SMMessageThread *_selectedMessageThread;
	SMMessageThread *_draggedMessageThread;
	NSMutableArray *_multipleSelectedMessageThreads;
	Boolean _immediateSelection;
	Boolean _mouseSelectionInProcess;
	Boolean _reloadDeferred;
    NSArray *_selectedMessageThreadsForContextMenu;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

	if(self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageBodyFetched:) name:@"MessageBodyFetched" object:nil];
		
		_multipleSelectedMessageThreads = [NSMutableArray array];
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
	SMMessageListController *messageListController = [[appDelegate model] messageListController];
	
	SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
	NSInteger messageThreadsCount = [[[appDelegate model] messageStorage] messageThreadsCountInLocalFolder:[currentFolder localName]];

    SM_LOG_DEBUG(@"self %@, tableView %@, its datasource %@, view %@, messagesTableView %@, message threads count %ld", self, tableView, [tableView dataSource], [self view], _messageListTableView, messageThreadsCount);
	
	return messageThreadsCount;
}

- (void)changeSelectedMessageThread {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	[[[appDelegate appController] messageThreadViewController] setMessageThread:_selectedMessageThread];
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
			SMMessageListController *messageListController = [[appDelegate model] messageListController];
			SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
			NSAssert(currentFolder != nil, @"bad corrent folder");
			
			_selectedMessageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:selectedRow localFolder:[currentFolder localName]];
			
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
		SMMessageStorage *storage = [[appDelegate model] messageStorage];
		SMMessageListController *messageListController = [[appDelegate model] messageListController];
		SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
		NSAssert(currentFolder != nil, @"bad corrent folder");
		
		// TODO: optimize later
		[_multipleSelectedMessageThreads removeAllObjects];

		NSUInteger selectedRow = [selectedRows firstIndex];
		while(selectedRow != NSNotFound) {
			SMMessageThread *messageThread = [storage messageThreadAtIndexByDate:selectedRow localFolder:[currentFolder localName]];
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
	
	SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
	SMAppController *appController = [appDelegate appController];
	SMMessageListController *messageListController = [[appDelegate model] messageListController];
	SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
	SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:row localFolder:[currentLocalFolder localName]];

	if(messageThread == nil) {
		SM_LOG_DEBUG(@"row %ld, message thread is nil", row);
		return nil;
	}
	
	NSAssert([messageThread messagesCount], @"no messages in the thread");
	SMMessage *message = [messageThread messagesSortedByDate][0];
	
	SMMessageListCellView *view = [tableView makeViewWithIdentifier:@"MessageCell" owner:self];
	NSAssert(view != nil, @"view is nil");

	[view initFields];

	SM_LOG_DEBUG(@"from '%@', subject '%@', unseen %u", [message from], [message subject], messageThread.unseen);
	
	[view.fromTextField setStringValue:[message from]];
	[view.subjectTextField setStringValue:[message subject]];
	[view.dateTextField setStringValue:[message localizedDate]];

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

    // the buttons within the table cells must know which row they're in
    // so their action will use this tag to reflect the button action to the
    // target message thread
    view.unseenButton.tag = row;
    view.starButton.tag = row;

    [self setToggleButtonAlpha:view.unseenButton];
    [self setToggleButtonAlpha:view.starButton];
    
	if(messageThread.hasAttachments) {
		[view showAttachmentImage];
	} else {
		[view hideAttachmentImage];
	}
	
    [view setMessagesCount:messageThread.messagesCount];
    
    SMFolder *currentFolder = nil;
	NSString *currentFolderName = [[appController mailboxViewController] currentFolderName];
    if(currentFolderName != nil) {
        SMFolder *currentFolder = [[[appDelegate model] mailbox] getFolderByName:currentFolderName];
        NSAssert(currentFolder != nil, @"currentFolder == nil");
    }

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
    } else {
        [view hideAttachmentImage];
    }

	return view;
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

- (void)reloadMessageList:(Boolean)preserveSelection {
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

	// after all is done, fix the currently selected
	// message cell, if needed
	if(preserveSelection) {
		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
		SMMessageStorage *messageStorage = [[appDelegate model] messageStorage];
		SMMessageListController *messageListController = [[appDelegate model] messageListController];
		SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
		NSAssert(currentFolder != nil, @"no current folder");
		
		if(_selectedMessageThread != nil) {
			NSAssert(_multipleSelectedMessageThreads.count == 0, @"multiple messages selection not empty");

			NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:_selectedMessageThread localFolder:currentFolder.localName];
			
			if(threadIndex != NSNotFound) {
				[_messageListTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:threadIndex] byExtendingSelection:NO];
				return;
			}
		} else {
			NSMutableIndexSet *threadIndexes = [NSMutableIndexSet indexSet];
			
			for(SMMessageThread *t in _multipleSelectedMessageThreads) {
				NSUInteger threadIndex = [messageStorage getMessageThreadIndexByDate:t localFolder:currentFolder.localName];
				
				if(threadIndex != NSNotFound)
					[threadIndexes addIndex:threadIndex];
			}

			if(threadIndexes.count != 0) {
				[_messageListTableView selectRowIndexes:threadIndexes byExtendingSelection:NO];
				return;
			}
		}
	}

	[_messageListTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];

	[_multipleSelectedMessageThreads removeAllObjects];

	_selectedMessageThread = nil;
}

- (IBAction)updateMessagesNow:(id)sender {
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	SMMessageListController *messageListController = [[appDelegate model] messageListController];

	[messageListController cancelMessageListUpdate];
	[messageListController scheduleMessageListUpdate:YES];

	[_updatingMessagesProgressIndicator setHidden:NO];
	[_updatingMessagesProgressIndicator startAnimation:self];
}

- (IBAction)loadMoreMessages:(id)sender {
    SM_LOG_DEBUG(@"sender %@", sender);

	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	SMMessageListController *messageListController = [[appDelegate model] messageListController];

	SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
	if(currentFolder != nil && [currentFolder messageHeadersAreBeingLoaded] == NO) {
		[currentFolder increaseLocalFolderCapacity];
		[messageListController scheduleMessageListUpdate:YES];

		[_loadingMoreMessagesProgressIndicator setHidden:NO];
		[_loadingMoreMessagesProgressIndicator startAnimation:self];
	}
}

- (void)messageHeadersSyncFinished:(Boolean)hasUpdates {
	[self stopProgressIndicators];

	if(hasUpdates) {
		const Boolean preserveSelection = YES;
		[self reloadMessageList:preserveSelection];
		
		SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
		[[[appDelegate appController] messageThreadViewController] updateMessageThread];
	}
}

- (void)messageBodyFetched:(NSNotification *)notification {
	NSDictionary *messageInfo = [notification userInfo];
	
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	SMMessageListController *messageListController = [[appDelegate model] messageListController];
	SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
	
	if(currentFolder != nil) {
		uint64_t threadId = [[messageInfo objectForKey:@"ThreadId"] unsignedLongLongValue];
		SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadById:threadId localFolder:currentFolder.localName];
		
		if(messageThread != nil) {
			uint32_t uid = [[messageInfo objectForKey:@"UID"] unsignedIntValue];

			if([messageThread updateThreadAttributesFromMessageUID:uid]) {
				NSUInteger threadIndex = [[[appDelegate model] messageStorage] getMessageThreadIndexByDate:messageThread localFolder:currentFolder.localName];
				
				if(threadIndex != NSNotFound) {
					[_messageListTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:threadIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
				}
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
	SMMessageListController *messageListController = [[appDelegate model] messageListController];

	if(_selectedMessageThread == nil && _multipleSelectedMessageThreads.count == 0 && _draggedMessageThread == nil) {
		SM_LOG_DEBUG(@"no message threads selected for moving");
		return;
	}

	NSArray *messageThreadsToMove = _selectedMessageThread != nil? [NSArray arrayWithObject:_selectedMessageThread] : _multipleSelectedMessageThreads.count > 0? [NSArray arrayWithArray:_multipleSelectedMessageThreads] : [NSArray arrayWithObject:_draggedMessageThread];
	
	SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
	NSAssert(currentFolder != nil, @"no current folder");

	[currentFolder moveMessageThreads:messageThreadsToMove toRemoteFolder:remoteFolderName];

    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];

    if(selectedRows.count > 0) {
        // Move the selection down after the message thread is deleted from the list.
        NSUInteger nextRow = selectedRows.firstIndex;
        _selectedMessageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:nextRow localFolder:[currentFolder localName]];
        
        // If there's no down, move the selection up.
        if(_selectedMessageThread == nil && nextRow > 0) {
            nextRow--;
            _selectedMessageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:nextRow localFolder:[currentFolder localName]];
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
			SMMessageListController *messageListController = [[appDelegate model] messageListController];
			SMLocalFolder *currentFolder = [messageListController currentLocalFolder];
			NSAssert(currentFolder != nil, @"no current folder");

			_draggedMessageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:rowIndexes.firstIndex localFolder:[currentFolder localName]];
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
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:row localFolder:[currentLocalFolder localName]];
    
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
    [[[[appDelegate model] messageListController] currentLocalFolder] setMessageFlagged:message flagged:YES];
    
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
        [[[[appDelegate model] messageListController] currentLocalFolder] setMessageFlagged:message flagged:NO];

        [messageThread updateThreadAttributesFromMessageUID:message.uid];
    }
}

- (IBAction)toggleUnseenAction:(id)sender {
    NSButton *button = (NSButton*)sender;
    [self setToggleButtonAlpha:button];
    
    NSInteger row = button.tag;
    
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
    SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:row localFolder:[currentLocalFolder localName]];
    
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
            [[[[appDelegate model] messageListController] currentLocalFolder] setMessageUnseen:message unseen:NO];
            [messageThread updateThreadAttributesFromMessageUID:message.uid];
        }
    }
    else {
        //
        // TODO: Use not just the first message, but the first message that belongs to this remote folder
        //
        SMMessage *message = messageThread.messagesSortedByDate[0];
        
        [[[[appDelegate model] messageListController] currentLocalFolder] setMessageUnseen:message unseen:!message.unseen];
        [messageThread updateThreadAttributesFromMessageUID:message.uid];
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
}

#pragma mark Context menu creation

- (NSMenu*)menuForRow:(NSInteger)row {
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];

    NSMutableArray *messageThreads = [NSMutableArray array];
    
    NSIndexSet *selectedRows = [_messageListTableView selectedRowIndexes];
    if(![selectedRows containsIndex:row]) {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
        [_messageListTableView selectRowIndexes:indexSet byExtendingSelection:NO];

        [self reloadMessageList:YES];
        
        SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:row localFolder:[currentLocalFolder localName]];
        
        if(messageThread == nil) {
            // TODO: fix this logic
            return nil;
        }

        [messageThreads addObject:[NSNumber numberWithUnsignedLong:messageThread.threadId]];
    }
    else {
        NSUInteger selectedRow = [selectedRows firstIndex];
        while(selectedRow != NSNotFound) {
            SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:selectedRow localFolder:[currentLocalFolder localName]];
            NSAssert(messageThread != nil, @"message thread at selected row %lu not found", selectedRow);
            
            [messageThreads addObject:[NSNumber numberWithUnsignedLong:messageThread.threadId]];
            
            selectedRow = [selectedRows indexGreaterThanIndex:selectedRow];
        }
    }

    _selectedMessageThreadsForContextMenu = messageThreads;
    
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    NSMenuItem *item = [menu addItemWithTitle:@"Reply" action:@selector(menuActionReply:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:_selectedMessageThreadsForContextMenu.count == 1];

    item = [menu addItemWithTitle:@"Reply All" action:@selector(menuActionReplyAll:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:_selectedMessageThreadsForContextMenu.count == 1];
    
    item = [menu addItemWithTitle:@"Forward" action:@selector(menuActionForward:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:_selectedMessageThreadsForContextMenu.count == 1];
    
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:@"Delete" action:@selector(menuActionDelete:) keyEquivalent:@""] setTarget:self];
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:@"Mark as Read" action:@selector(menuActionMarkAsSeen:) keyEquivalent:@""] setTarget:self];
    [[menu addItemWithTitle:@"Mark as Unread" action:@selector(menuActionMarkAsUnseen:) keyEquivalent:@""] setTarget:self];
    [[menu addItemWithTitle:@"Add Star" action:@selector(menuActionAddStar:) keyEquivalent:@""] setTarget:self];
    [[menu addItemWithTitle:@"Remove Star" action:@selector(menuActionRemoveStar:) keyEquivalent:@""] setTarget:self];
    
    return menu;
}

- (void)menuActionReply:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Reply", @"ReplyKind", nil]];
}

- (void)menuActionReplyAll:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"ReplyAll", @"ReplyKind", nil]];
}

- (void)menuActionForward:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Forward", @"ReplyKind", nil]];
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
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSNumber *threadIdNumber in _selectedMessageThreadsForContextMenu) {
        uint64_t threadId = [threadIdNumber unsignedLongLongValue];
        SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadById:threadId localFolder:[currentLocalFolder localName]];

        if(messageThread != nil) {
            [self addStarToMessageThread:messageThread];
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)menuActionRemoveStar:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSNumber *threadIdNumber in _selectedMessageThreadsForContextMenu) {
        uint64_t threadId = [threadIdNumber unsignedLongLongValue];
        SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadById:threadId localFolder:[currentLocalFolder localName]];
        
        if(messageThread != nil) {
            [self removeStarFromMessageThread:messageThread];
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (void)markMessageThreadsAsUnseen:(Boolean)unseen {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *currentLocalFolder = [messageListController currentLocalFolder];
    
    for(NSNumber *threadIdNumber in _selectedMessageThreadsForContextMenu) {
        uint64_t threadId = [threadIdNumber unsignedLongLongValue];
        SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadById:threadId localFolder:[currentLocalFolder localName]];
        
        if(messageThread != nil) {
            for(SMMessage *message in messageThread.messagesSortedByDate) {
                [[[[appDelegate model] messageListController] currentLocalFolder] setMessageUnseen:message unseen:unseen];
                [messageThread updateThreadAttributesFromMessageUID:message.uid];
            }
        }
    }
    
    [[[appDelegate appController] messageThreadViewController] updateMessageThread];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

#pragma mark Opening message in window

- (void)openMessageInWindow:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMMessageListController *messageListController = [[appDelegate model] messageListController];
    SMLocalFolder *localFolder = messageListController.currentLocalFolder;
    
    if(localFolder == nil) {
        SM_LOG_DEBUG(@"no local folder");
        return;
    }
    
    SMMessageThread *messageThread = [[[appDelegate model] messageStorage] messageThreadAtIndexByDate:_messageListTableView.clickedRow localFolder:localFolder.localName];

    NSAssert(messageThread != nil, @"messageThread is nil");

    for(SMMessage *m in messageThread.messagesSortedByDate) {
        NSAssert(m != nil, @"messageToOpen is nil");

        SMFolder *messageFolder = [[[appDelegate model] mailbox] getFolderByName:m.remoteFolder];
        
        if(messageFolder != nil && messageFolder.kind == SMFolderKindDrafts) {
            if(m.htmlBodyRendering != nil) {
                [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering subject:m.subject to:[m parsedToAddressList] cc:[m parsedCcAddressList] bcc:nil draftUid:m.uid mcoAttachments:m.attachments];
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
        }
    }
}

@end
