//
//  SMSearchResultsListViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMSimplicityContainer.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMSearchDescriptor.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxViewController.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMSearchResultsListCellView.h"
#import "SMSearchResultsListViewController.h"

@implementation SMSearchResultsListViewController {
	NSMutableDictionary *_cellViews;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		_cellViews = [[NSMutableDictionary alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
	}
	
	return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSInteger rowCount = [[[appDelegate model] searchResultsListController] searchResultsCount];
	
	if(rowCount < _cellViews.count) {
		for(NSInteger r = rowCount, rc = _cellViews.count; r < rc; r++)
			[_cellViews removeObjectForKey:[NSNumber numberWithInteger:r]];
	}

	return rowCount;
}

- (SMSearchResultsListCellView*)getSearchResultCell:(NSTableView *)tableView row:(NSInteger)row {
	NSNumber *rowNumber = [NSNumber numberWithInteger:row];
	
	SMSearchResultsListCellView *result = [_cellViews objectForKey:[NSNumber numberWithInteger:row]];

	if(result == nil) {
		NSArray *topLevelObjects = [[NSArray alloc] init];
		Boolean loadResult = [[NSBundle mainBundle] loadNibNamed:@"SMSearchResultsListCellView" owner:self topLevelObjects:&topLevelObjects];
		
		NSAssert(loadResult, @"Cannot load search results list cell");
		
		// TODO: looks stupid, find out a better way
		for(id object in topLevelObjects) {
			if([object isKindOfClass:[SMSearchResultsListCellView class]]) {
				result = object;
				break;
			}
		}
		
		NSAssert(result != nil, @"bad top objects");

		result.searchResultsListRow = rowNumber;

		[_cellViews setObject:result forKey:rowNumber];
	} else {
		NSAssert(result.searchResultsListRow == rowNumber, @"search results list cell row is invalid");
	}
	
	return result;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	SMSearchResultsListCellView *result = [self getSearchResultCell:tableView row:row];
	NSAssert(result != nil, @"bad cell found");

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMSearchDescriptor *searchResults = [[[appDelegate model] searchResultsListController] getSearchResults:row];
	NSAssert(searchResults != nil, @"no search results");

	NSString *searchPattern = [searchResults searchPattern];
	NSAssert(searchPattern != nil, @"no search pattern");

	SM_LOG_DEBUG(@"row %ld, searchPattern '%@', searchFailed %d, searchStopped %d", row, searchResults.searchPattern, searchResults.searchFailed, searchResults.searchStopped);

	Boolean stopProgress = NO;
	
	if(!searchResults.searchFailed && !searchResults.searchStopped) {
		NSString *searchLocalFolderName = searchResults.localFolder;
		SMLocalFolder *searchFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:searchLocalFolderName];

		SM_LOG_DEBUG(@"messagesLoadingStarted %d, searchFolder.isStillUpdating %d", searchResults.messagesLoadingStarted, [searchFolder messageHeadersAreBeingLoaded]);

		if(!searchResults.messagesLoadingStarted) {
			[result.progressIndicator setIndeterminate:YES];
			[result.progressIndicator startAnimation:self];
		} else if([searchFolder messageHeadersAreBeingLoaded]) {
			if([result.progressIndicator isIndeterminate])
				[result.progressIndicator setIndeterminate:NO];
			
			double loadRatio = (searchFolder.messageHeadersFetched * 100) / (double)searchFolder.totalMessagesCount;

			[result.progressIndicator setDoubleValue:loadRatio];
		} else {
			SM_LOG_DEBUG(@"stopping progress indicator (case 1)...");
			stopProgress = YES;
		}
	} else {
		SM_LOG_DEBUG(@"stopping progress indicator (case 2)...");
		stopProgress = YES;
	}
	
	if(stopProgress) {
		[result.progressIndicator setIndeterminate:YES];
		[result.progressIndicator setDisplayedWhenStopped:NO];
		[result.progressIndicator stopAnimation:self];
	}

	[result.progressIndicator setNeedsDisplay:YES];

	result.textField.stringValue = searchPattern;

	return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	SMSearchResultsListCellView *result = [self getSearchResultCell:tableView row:row];
	NSAssert(result != nil, @"bad cell found");

	return result.frame.size.height;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSInteger selectedRow = [_tableView selectedRow];
	
	if(selectedRow >= 0) {
		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
		SMSearchResultsListController *searchResultsListController = [[appDelegate model] searchResultsListController];
		
		if(selectedRow < searchResultsListController.searchResultsCount) {
			NSString *localFolder = [[searchResultsListController getSearchResults:selectedRow] localFolder];
			[[[appDelegate model] messageListController] changeFolder:localFolder];

			[[[appDelegate appController] mailboxViewController] clearSelection];
		}
	}
}

- (void)reloadData {
	NSInteger selectedRow = [_tableView selectedRow];

	[_tableView reloadData];
	
	if([_tableView numberOfRows] > 0) {
		if(selectedRow == [_tableView numberOfRows])
			--selectedRow;

		[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
	}
}

- (void)clearSelection {
	[_tableView deselectAll:self];
}

- (void)messagesUpdated:(NSNotification *)notification {
	NSString *localFolder = [[notification userInfo] objectForKey:@"LocalFolderName"];
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSInteger index = [[[appDelegate model] searchResultsListController] getSearchIndex:localFolder];

	if(index >= 0) {
		SM_LOG_DEBUG(@"reloading table");
		[self reloadData];
	}
}

- (void)selectSearchResult:(NSString*)searchResultsLocalFolder {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSInteger index = [[[appDelegate model] searchResultsListController] getSearchIndex:searchResultsLocalFolder];
	
	if(index >= 0) {
		[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[_tableView setNeedsDisplay:YES];
	}
}

- (void)removeSearch:(NSInteger)index {
	SM_LOG_DEBUG(@"request for index %ld", index);
	
	[self stopSearch:index];
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSString *localFolder = [[[[appDelegate model] searchResultsListController] getSearchResults:index] localFolder];
	
	[[[appDelegate model] localFolderRegistry] removeLocalFolder:localFolder];
	[[[appDelegate model] searchResultsListController] removeSearch:index];

	if([_tableView selectedRow] == index) {
		[self clearSelection];

		[[[appDelegate model] messageListController] clearCurrentFolderSelection];
	}

	[self reloadData];
}

- (void)reloadSearch:(NSInteger)index {
	SM_LOG_DEBUG(@"request for index %ld", index);
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] searchResultsListController] reloadSearch:index];

	[self reloadData];
}

- (void)stopSearch:(NSInteger)index {
	SM_LOG_DEBUG(@"request for index %ld", index);
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	if(![[[appDelegate model] searchResultsListController] searchStopped:index]) {
		[[[appDelegate model] searchResultsListController] stopSearch:index];
		
		[self reloadData];
	}
}

@end
