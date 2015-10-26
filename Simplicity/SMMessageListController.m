//
//  SMMessageListUpdater.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/12/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMSimplicityContainer.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolder.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"

static NSUInteger MESSAGE_LIST_UPDATE_INTERVAL_SEC = 30;

@interface SMMessageListController()
- (void)startMessagesUpdate;
@end

@implementation SMMessageListController {
	__weak SMSimplicityContainer *_model;
	SMLocalFolder *_currentFolder;
	MCOIMAPFolderInfoOperation *_folderInfoOp;
}

- (id)initWithModel:(SMSimplicityContainer*)model {
	self = [ super init ];
	
	if(self) {
		_model = model;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
	}

	return self;
}

- (SMLocalFolder*)currentLocalFolder {
	return _currentFolder;
}

- (void)changeFolderInternal:(NSString*)folderName remoteFolder:(NSString*)remoteFolderName syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
	SM_LOG_DEBUG(@"new folder '%@'", folderName);

	if(folderName != nil) {
		SMLocalFolder *folder = [[_model localFolderRegistry] getLocalFolder:folderName];
		
		if(folder == nil)
			folder = [[_model localFolderRegistry] createLocalFolder:folderName remoteFolder:remoteFolderName syncWithRemoteFolder:syncWithRemoteFolder];
		
		NSAssert(folder != nil, @"folder registry returned nil folder");

		_currentFolder = folder;
	} else {
		_currentFolder = nil;
	}

	if([_currentFolder syncedWithRemoteFolder])
		[_currentFolder stopMessagesLoading:NO];
	
	[_folderInfoOp cancel];
	_folderInfoOp = nil;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel scheduled message list update
}

- (void)changeFolder:(NSString*)folder {
	if([_currentFolder.localName isEqualToString:folder])
		return;

	[self changeFolderInternal:folder remoteFolder:folder syncWithRemoteFolder:YES];
	[self startMessagesUpdate];
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];
	
	Boolean preserveSelection = NO;
	[[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)clearCurrentFolderSelection {
	if(_currentFolder == nil)
		return;
	
	[self changeFolderInternal:nil remoteFolder:nil syncWithRemoteFolder:NO];
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];
	
	Boolean preserveSelection = NO;
	[[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)startMessagesUpdate {
	SM_LOG_DEBUG(@"updating message list");

	[_currentFolder startLocalFolderSync];
}

- (void)cancelMessageListUpdate {
	[_currentFolder stopMessagesLoading:NO];
}

- (void)loadSearchResults:(MCOIndexSet*)searchResults remoteFolderToSearch:(NSString*)remoteFolderNameToSearch searchResultsLocalFolder:(NSString*)searchResultsLocalFolder {
	[self changeFolderInternal:searchResultsLocalFolder remoteFolder:remoteFolderNameToSearch syncWithRemoteFolder:NO];
	
	[_currentFolder loadSelectedMessages:searchResults];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];
	
	Boolean preserveSelection = NO;
	[[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)updateMessageList {
	//TODO:
	//if(updateResult == SMMesssageStorageUpdateResultNone) {
		// no updates, so no need to reload the message list
	//	return;
	//}
	
	// TODO: special case for flags changed in some cells only
	
	SM_LOG_DEBUG(@"some messages updated, the list will be reloaded");
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];

	Boolean preserveSelection = YES;
	[[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)updateMessageThreadView {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMAppController *appController = [appDelegate appController];
	
	[[appController messageThreadViewController] updateMessageThread];
}

- (void)cancelScheduledMessageListUpdate {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startMessagesUpdate) object:nil];
}

- (void)scheduleMessageListUpdate:(Boolean)now {
	[self cancelScheduledMessageListUpdate];
	
	NSTimeInterval delay_sec = now? 0 : MESSAGE_LIST_UPDATE_INTERVAL_SEC;
	
	SM_LOG_DEBUG(@"scheduling message list update after %lu sec", (unsigned long)delay_sec);

	[self performSelector:@selector(startMessagesUpdate) withObject:nil afterDelay:delay_sec];
}

- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
	SM_LOG_DEBUG(@"msg uid %u, remote folder %@, threadId %llu", uid, remoteFolderName, threadId);

	[_currentFolder fetchMessageBodyUrgently:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId];
}

- (void)messagesUpdated:(NSNotification *)notification {
	NSString *localFolder = [[notification userInfo] objectForKey:@"LocalFolderName"];

	if([_currentFolder.localName isEqualToString:localFolder]) {
		[self updateMessageList];
		[self updateMessageThreadView];
	}
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
	NSString *localFolder = [[notification userInfo] objectForKey:@"LocalFolderName"];

	if([_currentFolder.localName isEqualToString:localFolder]) {
		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
		SMAppController *appController = [appDelegate appController];
		
		NSNumber *hasUpdatesNumber = [[notification userInfo] objectForKey:@"HasUpdates"];
		Boolean hasUpdates = [hasUpdatesNumber boolValue];

		[[appController messageListViewController] messageHeadersSyncFinished:hasUpdates];
	}
}

@end
