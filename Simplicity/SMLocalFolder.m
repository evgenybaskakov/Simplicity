//
//  SMLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMMessageStorage.h"
#import "SMAppController.h"
#import "SMMessageListController.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMLocalFolder.h"

static const NSUInteger DEFAULT_MAX_MESSAGES_PER_FOLDER = 100;
static const NSUInteger INCREASE_MESSAGES_PER_FOLDER = 50;
static const NSUInteger MESSAGE_HEADERS_TO_FETCH_AT_ONCE = 20;
static const NSUInteger OPERATION_UPDATE_TIMEOUT_SEC = 30;

static const MCOIMAPMessagesRequestKind messageHeadersRequestKind = (MCOIMAPMessagesRequestKind)(
	MCOIMAPMessagesRequestKindUid |
	MCOIMAPMessagesRequestKindFlags |
	MCOIMAPMessagesRequestKindHeaders |
	MCOIMAPMessagesRequestKindStructure |
	MCOIMAPMessagesRequestKindInternalDate |
	MCOIMAPMessagesRequestKindFullHeaders |
	MCOIMAPMessagesRequestKindHeaderSubject |
	MCOIMAPMessagesRequestKindGmailLabels |
	MCOIMAPMessagesRequestKindGmailMessageID |
	MCOIMAPMessagesRequestKindGmailThreadID |
	MCOIMAPMessagesRequestKindExtraHeaders |
	MCOIMAPMessagesRequestKindSize
);

@implementation SMLocalFolder {
	MCOIMAPFolderInfoOperation *_folderInfoOp;
	MCOIMAPFetchMessagesOperation *_fetchMessageHeadersOp;
	NSMutableDictionary *_fetchMessageBodyOps;
	NSMutableDictionary *_searchMessageThreadsOps;
	NSMutableDictionary *_fetchMessageThreadsHeadersOps;
	NSMutableDictionary *_fetchedMessageHeaders;
	NSMutableArray *_fetchedMessageHeadersFromAllMail;
	NSString *_selectedMessagesRemoteFolder;
	MCOIndexSet *_selectedMessageUIDsToLoad;
}

- (id)initWithLocalFolderName:(NSString*)localFolderName syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
	self = [ super init ];
	
	if(self) {
		_localName = localFolderName;
		_maxMessagesPerThisFolder = DEFAULT_MAX_MESSAGES_PER_FOLDER;
		_totalMessagesCount = 0;
		_messageHeadersFetched = 0;
		_fetchedMessageHeaders = [NSMutableDictionary new];
		_fetchedMessageHeadersFromAllMail = [NSMutableArray new];
		_fetchMessageBodyOps = [NSMutableDictionary new];
		_fetchMessageThreadsHeadersOps = [NSMutableDictionary new];
		_searchMessageThreadsOps = [NSMutableDictionary new];
		_syncedWithRemoteFolder = syncWithRemoteFolder;
		_selectedMessageUIDsToLoad = nil;
		_selectedMessagesRemoteFolder = nil;
	}
	
	return self;
}

- (void)rescheduleMessageListUpdate {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageListController] scheduleMessageListUpdate:NO];
}

- (void)cancelScheduledUpdateTimeout {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTimeout) object:nil];
}

- (void)rescheduleUpdateTimeout {
	[self cancelScheduledUpdateTimeout];

	[self performSelector:@selector(updateTimeout) withObject:nil afterDelay:OPERATION_UPDATE_TIMEOUT_SEC];
}

- (void)updateTimeout {
	NSLog(@"%s: operation timeout", __func__);

	[self stopMessagesLoading:NO];
	[self startLocalFolderSync];
	[self rescheduleUpdateTimeout];
}

- (void)startLocalFolderSync {
	[self rescheduleMessageListUpdate];

	if(_folderInfoOp != nil || _fetchMessageHeadersOp != nil || _fetchMessageThreadsHeadersOps.count > 0) {
		NSLog(@"%s: previous op is still in progress for folder %@", __func__, _localName);
		return;
	}
	
	if(!_syncedWithRemoteFolder) {
		[self loadSelectedMessagesInternal];
		return;
	}
	
	_messageHeadersFetched = 0;
	
	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
	[[[appDelegate model] messageStorage] startUpdate:_localName];
	
	MCOIMAPSession *session = [[appDelegate model] session];
	
	NSAssert(session, @"session lost");

	// TODO: handle session reopening/uids validation	
	
	_folderInfoOp = [session folderInfoOperation:_localName];
	_folderInfoOp.urgent = YES;

	[_folderInfoOp start:^(NSError *error, MCOIMAPFolderInfo *info) {
		_folderInfoOp = nil;

		if(error == nil) {
//			NSLog(@"UIDNEXT: %lu", (unsigned long) [info uidNext]);
//			NSLog(@"UIDVALIDITY: %lu", (unsigned long) [info uidValidity]);
//			NSLog(@"Messages count %u", [info messageCount]);
			
			_totalMessagesCount = [info messageCount];
			
			[self syncFetchMessageHeaders];
		} else {
			NSLog(@"Error fetching folder info: %@", error);
		}
	}];
}

- (void)increaseLocalFolderCapacity {
	if(![self folderUpdateIsInProgress]) {
		if(_messageHeadersFetched + INCREASE_MESSAGES_PER_FOLDER < _totalMessagesCount)
			_maxMessagesPerThisFolder += INCREASE_MESSAGES_PER_FOLDER;
	}
}

- (Boolean)folderUpdateIsInProgress {
	return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)fetchMessageBodies:(NSString*)remoteFolderName {
	NSLog(@"%s: fetching message bodies for folder '%@' (%lu messages in this folder, %lu messages in all mail)", __FUNCTION__, remoteFolderName, _fetchedMessageHeaders.count, _fetchedMessageHeadersFromAllMail.count);
	
	NSUInteger fetchCount = 0;
	
	NSEnumerator *enumerator = [_fetchedMessageHeaders keyEnumerator];
	for(NSNumber *gmailMessageId = nil; gmailMessageId = [enumerator nextObject];) {
		//NSLog(@"fetched message id %@", gmailMessageId);

		MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];

		if([self fetchMessageBody:message.uid remoteFolder:remoteFolderName threadId:message.gmailThreadID urgent:NO])
			fetchCount++;
	}

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];

	for(MCOIMAPMessage *message in _fetchedMessageHeadersFromAllMail) {
		//NSLog(@"[all mail] fetched message id %llu", message.gmailMessageID);

		if([self fetchMessageBody:message.uid remoteFolder:allMailFolder threadId:message.gmailThreadID urgent:NO])
			fetchCount++;
	}

	NSLog(@"%s: fetching %lu message bodies", __func__, fetchCount);

	[_fetchedMessageHeaders removeAllObjects];
	[_fetchedMessageHeadersFromAllMail removeAllObjects];
}

- (BOOL)fetchMessageBody:(uint32_t)uid remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent {
	//	NSLog(@"%s: uid %u, remote folder %@, threadId %llu, urgent %s", __FUNCTION__, uid, remoteFolder, threadId, urgent? "YES" : "NO");

	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

	if([[[appDelegate model] messageStorage] messageHasData:uid localFolder:_localName threadId:threadId])
		return NO;
	
	MCOIMAPSession *session = [[appDelegate model] session];
	
	NSAssert(session, @"session is nil");
	
	MCOIMAPFetchContentOperation *op = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
	
	[_fetchMessageBodyOps setObject:op forKey:[NSNumber numberWithUnsignedInt:uid]];
	
	void (^opBlock)(NSError *error, NSData * data) = nil;

	opBlock = ^(NSError * error, NSData * data) {
		//	NSLog(@"%s: msg uid %u", __FUNCTION__, uid);
		
		if ([error code] != MCOErrorNone) {
			NSLog(@"%s: Error downloading message body for uid %u, remote folder %@", __func__, uid, remoteFolderName);

			MCOIMAPFetchContentOperation *op = [_fetchMessageBodyOps objectForKey:[NSNumber numberWithUnsignedInt:uid]];

			// restart this message body fetch to prevent data loss
			// on connectivity/server problems
			[op start:opBlock];

			return;
		}
		
		[_fetchMessageBodyOps removeObjectForKey:[NSNumber numberWithUnsignedInt:uid]];
		
		NSAssert(data != nil, @"data != nil");
		
		[[[appDelegate model] messageStorage] setMessageData:data uid:uid localFolder:_localName threadId:threadId];
		
		NSDictionary *messageInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInteger:uid], [NSNumber numberWithUnsignedLongLong:threadId], nil] forKeys:[NSArray arrayWithObjects:@"UID", @"ThreadId", nil]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:messageInfo];
	};
	
	// TODO: don't fetch if body is already being fetched (non-urgently!)
	// TODO: if urgent fetch is requested, cancel the non-urgent fetch
	[op start:opBlock];
	
	return YES;
}

- (void)syncFetchMessageThreadsHeaders {
	NSLog(@"%s: searching for %lu threads", __func__, _fetchedMessageHeaders.count);

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] session];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];
	
	NSAssert(_searchMessageThreadsOps.count == 0, @"_searchMessageThreadsOps not empty");

	if(_fetchedMessageHeaders.count == 0) {
		[self finishHeadersSync];
		return;
	}

	NSMutableSet *threadIds = [[NSMutableSet alloc] init];
	NSEnumerator *enumerator = [_fetchedMessageHeaders keyEnumerator];
	for(NSNumber *gmailMessageId = nil; gmailMessageId = [enumerator nextObject];) {
		MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];
		NSNumber *threadId = [NSNumber numberWithUnsignedLongLong:message.gmailThreadID];
		
		if([threadIds containsObject:threadId])
			continue;
		
		MCOIMAPSearchExpression *expression = [MCOIMAPSearchExpression searchGmailThreadID:message.gmailThreadID];
		MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:allMailFolder expression:expression];
		
		op.urgent = YES;
		
		[op start:^(NSError *error, MCOIndexSet *searchResults) {
			if([_searchMessageThreadsOps objectForKey:threadId] != op)
				return;

			[self rescheduleUpdateTimeout];
			
			[_searchMessageThreadsOps removeObjectForKey:threadId];
			
			if(error == nil) {
				//NSLog(@"Search for message '%@' thread %llu finished (%lu searches left)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);

				if(searchResults.count > 0) {
					//NSLog(@"%s: %u messages found in '%@', threadId %@", __func__, [searchResults count], allMailFolder, threadId);
					
					[self fetchMessageThreadsHeaders:threadId uids:searchResults];
				}
			} else {
				NSLog(@"%s: search in '%@' for thread %@ failed, error %@", __func__, allMailFolder, threadId, error);

				[self markMessageThreadAsUpdated:threadId];
			}
		}];
		
		[_searchMessageThreadsOps setObject:op forKey:threadId];

		//NSLog(@"Search for message '%@' thread %llu started (%lu searches active)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);
	}
}

- (void)markMessageThreadAsUpdated:(NSNumber*)threadId {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];

	[storage markMessageThreadAsUpdated:[threadId unsignedLongLongValue] localFolder:_localName];
}

- (void)updateMessages:(NSArray*)imapMessages remoteFolder:(NSString*)remoteFolderName {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] session];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];
	
	SMMessageStorageUpdateResult updateResult = [storage updateIMAPMessages:imapMessages localFolder:_localName remoteFolder:remoteFolderName session:session];
	
	// TODO: send result
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MessagesUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_localName, @"LocalFolderName", nil]];
}

- (void)fetchMessageThreadsHeaders:(NSNumber*)threadId uids:(MCOIndexSet*)messageUIDs {
	//NSLog(@"%s: total %u messages to load", __func__, _selectedMessageUIDsToLoad.count);

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] session];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];

	MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:allMailFolder requestKind:messageHeadersRequestKind uids:messageUIDs];
	
	[op start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		if([_fetchMessageThreadsHeadersOps objectForKey:threadId] != op)
			return;
		
		[self rescheduleUpdateTimeout];

		[_fetchMessageThreadsHeadersOps removeObjectForKey:threadId];
		
		if(error == nil) {
			NSMutableArray *filteredMessages = [NSMutableArray array];
			for(MCOIMAPMessage *m in messages) {
				if([_fetchedMessageHeaders objectForKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]] == nil) {
					[_fetchedMessageHeadersFromAllMail addObject:m];
					[filteredMessages addObject:m];
				}
			}

			[self updateMessages:filteredMessages remoteFolder:allMailFolder];
		} else {
			NSLog(@"Error fetching message headers for thread %@: %@", threadId, error);
			
			[self markMessageThreadAsUpdated:threadId];
		}
		
		if(_searchMessageThreadsOps.count == 0 && _fetchMessageThreadsHeadersOps.count == 0)
			[self finishHeadersSync];
	}];

	[_fetchMessageThreadsHeadersOps setObject:op forKey:threadId];

	//NSLog(@"Fetching headers for thread %@ started (%lu fetches active)", threadId, _fetchMessageThreadsHeadersOps.count);
}

- (void)finishHeadersSync {
	[self cancelScheduledUpdateTimeout];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorageUpdateResult updateResult = [[[appDelegate model] messageStorage] endUpdate:_localName removeVanishedMessages:YES];
	Boolean hasUpdates = (updateResult != SMMesssageStorageUpdateResultNone);
	
	[self fetchMessageBodies:_localName];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_localName, @"LocalFolderName", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", nil]];
}

- (void)syncFetchMessageHeaders {
	NSAssert(_messageHeadersFetched <= _totalMessagesCount, @"invalid messageHeadersFetched");
	
	BOOL finishFetch = YES;
	
	if(_totalMessagesCount == _messageHeadersFetched) {
//		NSLog(@"%s: all %llu message headers fetched, stopping", __FUNCTION__, _totalMessagesCount);
	} else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
//		NSLog(@"%s: fetched %llu message headers, stopping", __FUNCTION__, _messageHeadersFetched);
	} else {
		finishFetch = NO;
	}
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	if(finishFetch) {
		[_fetchMessageHeadersOp cancel];
		_fetchMessageHeadersOp = nil;
		
		[self syncFetchMessageThreadsHeaders];
		
		return;
	}
	
	const uint64_t restOfMessages = _totalMessagesCount - _messageHeadersFetched;
	const uint64_t numberOfMessagesToFetch = MIN(restOfMessages, MESSAGE_HEADERS_TO_FETCH_AT_ONCE) - 1;
	const uint64_t fetchMessagesFromIndex = restOfMessages - numberOfMessagesToFetch;
	
	MCOIndexSet *regionToFetch = [MCOIndexSet indexSetWithRange:MCORangeMake(fetchMessagesFromIndex, numberOfMessagesToFetch)];
	MCOIMAPSession *session = [[appDelegate model] session];
	
	// TODO: handle session reopening/uids validation
	
	NSAssert(session, @"session lost");

	NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
	
	_fetchMessageHeadersOp = [session fetchMessagesByNumberOperationWithFolder:_localName requestKind:messageHeadersRequestKind numbers:regionToFetch];
	
	_fetchMessageHeadersOp.urgent = YES;
	
	[_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		[self rescheduleUpdateTimeout];

		_fetchMessageHeadersOp = nil;
		
		if(error == nil) {
			for(MCOIMAPMessage *m in messages)
				[_fetchedMessageHeaders setObject:m forKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]];

			_messageHeadersFetched += [messages count];

			[self updateMessages:messages remoteFolder:_localName];
			
			[self syncFetchMessageHeaders];
		} else {
			NSLog(@"Error downloading messages list: %@", error);
		}
	}];	
}

- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs remoteFolder:(NSString*)remoteFolderName {
	_messageHeadersFetched = 0;

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	[[[appDelegate model] messageStorage] startUpdate:_localName];
	
	_selectedMessagesRemoteFolder = remoteFolderName;
	_selectedMessageUIDsToLoad = messageUIDs;

	_totalMessagesCount = _selectedMessageUIDsToLoad.count;
	
	[self loadSelectedMessagesInternal];
}

- (void)loadSelectedMessagesInternal {
	if(_selectedMessagesRemoteFolder == nil) {
		NSLog(@"%s: remote folder is not set", __func__);
		return;
	}
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] session];
	
	NSAssert(session, @"session lost");

	NSAssert(_selectedMessageUIDsToLoad != nil, @"bad message uids to load array");
	
	BOOL finishFetch = YES;
	
	if(_totalMessagesCount == _messageHeadersFetched) {
//		NSLog(@"%s: all %llu message headers fetched, stopping", __FUNCTION__, _totalMessagesCount);
	} else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
//		NSLog(@"%s: fetched %llu message headers, stopping", __FUNCTION__, _messageHeadersFetched);
	} else if(_selectedMessageUIDsToLoad.count > 0) {
		finishFetch = NO;
	}
	
	if(finishFetch) {
		[[[appDelegate model] messageStorage] endUpdate:_localName removeVanishedMessages:NO];
		
		[self fetchMessageBodies:_selectedMessagesRemoteFolder];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObject:_localName forKey:@"LocalFolderName"]];

		return;
	}
	
	MCOIndexSet *const messageUIDsToLoadNow = [MCOIndexSet indexSet];
	MCORange *const ranges = [_selectedMessageUIDsToLoad allRanges];
	
	for(unsigned int i = [_selectedMessageUIDsToLoad rangesCount]; i > 0; i--) {
		const MCORange currentRange = ranges[i-1];
		const uint64_t len = MCORangeRightBound(currentRange) - MCORangeLeftBound(currentRange) + 1;
		const uint64_t maxCountToLoad = MESSAGE_HEADERS_TO_FETCH_AT_ONCE - messageUIDsToLoadNow.count;
		
		if(len < maxCountToLoad) {
			[messageUIDsToLoadNow addRange:currentRange];
		} else {
			// note: "- 1" is because zero length means one element range
			const MCORange range = MCORangeMake(MCORangeRightBound(currentRange) - maxCountToLoad + 1, maxCountToLoad - 1);
			
			[messageUIDsToLoadNow addRange:range];
			
			break;
		}
	}
	
	NSLog(@"%s: loading %u of %u search results...", __func__, messageUIDsToLoadNow.count, _selectedMessageUIDsToLoad.count);
	
	NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
	
	_fetchMessageHeadersOp = [session fetchMessagesOperationWithFolder:_selectedMessagesRemoteFolder requestKind:messageHeadersRequestKind uids:messageUIDsToLoadNow];
	
	_fetchMessageHeadersOp.urgent = YES;
	
	[_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		_fetchMessageHeadersOp = nil;
		
		if(error == nil) {
			NSLog(@"%s: loaded %lu message headers...", __func__, messages.count);

			[_selectedMessageUIDsToLoad removeIndexSet:messageUIDsToLoadNow];
			
			_messageHeadersFetched += [messages count];
			
			[self updateMessages:messages remoteFolder:_selectedMessagesRemoteFolder];
			
			[self loadSelectedMessagesInternal];
		} else {
			NSLog(@"%s: Error downloading search results: %@", __func__, error);
		}
	}];
}

- (Boolean)messageHeadersAreBeingLoaded {
	return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)stopMessageHeadersLoading {
	[self cancelScheduledUpdateTimeout];

	[_folderInfoOp cancel];
	_folderInfoOp = nil;
	
	[_fetchMessageHeadersOp cancel];
	_fetchMessageHeadersOp = nil;
	
	for(NSNumber *threadId in _searchMessageThreadsOps) {
		MCOIMAPBaseOperation *op = [_searchMessageThreadsOps objectForKey:threadId];
		[op cancel];
	}
	[_searchMessageThreadsOps removeAllObjects];
	
	for(NSNumber *threadId in _fetchMessageThreadsHeadersOps) {
		MCOIMAPBaseOperation *op = [_fetchMessageThreadsHeadersOps objectForKey:threadId];
		[op cancel];
	}
	[_fetchMessageThreadsHeadersOps removeAllObjects];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];
	
	[storage cancelUpdate:_localName];
}

- (void)stopMessagesLoading:(Boolean)stopBodiesLoading {
	[self stopMessageHeadersLoading];

	if(stopBodiesLoading) {
		for(NSNumber *uid in _fetchMessageBodyOps) {
//			NSLog(@"uid %@", uid);
			MCOIMAPFetchContentOperation *op = [_fetchMessageBodyOps objectForKey:uid];
			
			[op cancel];
		}
		
		[_fetchMessageBodyOps removeAllObjects];
	}
}

- (void)clear {
	[self stopMessagesLoading:YES];
	
	[_fetchedMessageHeaders removeAllObjects];
	[_fetchedMessageHeadersFromAllMail removeAllObjects];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageStorage] removeLocalFolder:_localName];
}

@end
