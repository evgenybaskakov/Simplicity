 //
//  SM_messagestorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMMessage.h"
#import "SMMessageComparators.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadCollection.h"
#import "SMAppDelegate.h"

@implementation SMMessageStorage {
@private
	// keeps a collection of message threads for each folder
	NSMutableDictionary *_foldersMessageThreadsMap;
}

@synthesize comparators;

- (id)init {
	self = [ super init ];

	if(self) {
		comparators = [SMMessageComparators new];
		
		_foldersMessageThreadsMap = [NSMutableDictionary new];
	}

	return self;
}

- (void)ensureLocalFolderExists:(NSString*)localFolder {
	//NSLog(@"%s: folder name '%@", __FUNCTION__, localFolder);
	
	SMMessageThreadCollection *collection = [_foldersMessageThreadsMap objectForKey:localFolder];
	
	if(collection == nil)
		[_foldersMessageThreadsMap setValue:[SMMessageThreadCollection new] forKey:localFolder];
}

- (void)removeLocalFolder:(NSString*)localFolder {
	[_foldersMessageThreadsMap removeObjectForKey:localFolder];
}

- (SMMessageThreadCollection*)messageThreadCollectionForFolder:(NSString*)folder {
	return [_foldersMessageThreadsMap objectForKey:folder];
}

- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread localFolder:(NSString*)localFolder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");
		
	NSMutableOrderedSet *sortedMessageThreads = collection.messageThreadsByDate;
	NSComparator messageThreadComparator = [comparators messageThreadsComparatorByDate];

	if([collection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:[messageThread threadId]]] != nil) {
		NSUInteger idx = [sortedMessageThreads indexOfObject:messageThread inSortedRange:NSMakeRange(0, sortedMessageThreads.count) options:NSBinarySearchingFirstEqual usingComparator:messageThreadComparator];
        
        NSAssert([sortedMessageThreads objectAtIndex:idx] == messageThread, @"message threads not the same object");

        return idx;
	} else {
		return NSNotFound;
	}
}

- (void)insertMessageThreadByDate:(SMMessageThread*)messageThread localFolder:(NSString*)localFolder oldIndex:(NSUInteger)oldIndex {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");
	NSMutableOrderedSet *sortedMessageThreads = collection.messageThreadsByDate;
	NSComparator messageThreadComparator = [comparators messageThreadsComparatorByDate];

	if(oldIndex != NSUIntegerMax) {
		NSAssert(collection.messageThreadsByDate.count == collection.messageThreads.count, @"message thread counts (sorted %lu, unsorted %lu) don't match", collection.messageThreadsByDate.count, collection.messageThreads.count);

		SMMessageThread *oldMessageThread = sortedMessageThreads[oldIndex];
		NSAssert(oldMessageThread == messageThread, @"bad message thread at index %lu (actual id %llu, expected id %llu)", oldIndex, oldMessageThread.threadId, messageThread.threadId);

		[sortedMessageThreads removeObjectAtIndex:oldIndex];
	}
	
	NSUInteger messageThreadIndexByDate = [sortedMessageThreads indexOfObject:messageThread inSortedRange:NSMakeRange(0, sortedMessageThreads.count) options:NSBinarySearchingInsertionIndex usingComparator:messageThreadComparator];
	
	NSAssert(messageThreadIndexByDate != NSNotFound, @"message thread not found");
	
	[sortedMessageThreads insertObject:messageThread atIndex:messageThreadIndexByDate];

	//TODO: remove/leave in debug mode only
/*
	//NSLog(@"validate threads");
	SMMessageThread *p = nil;
	for(id i in sortedMessageThreads) {
		SMMessageThread *t = i;
		//SMMessage *pi = t.messagesSortedByDate.firstObject;
		//NSLog(@"threadId %llu, date %@", t.threadId, pi.date);
		if(p != nil) {
			SMMessage *m = t.messagesSortedByDate.firstObject;
			SMMessage *pm = p.messagesSortedByDate.firstObject;
			NSComparisonResult r = [pm.date compare:m.date];
			NSAssert(r != NSOrderedAscending, @"threads not sorted");
		}
		p = i;
	}
*/
}

- (void)removeMessageThreads:(NSArray*)messageThreads fromLocalFolder:(NSString*)localFolder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");

	for(SMMessageThread *thread in messageThreads) {
		[collection.messageThreads removeObjectForKey:[NSNumber numberWithUnsignedLongLong:thread.threadId]];
		[collection.messageThreadsByDate removeObject:thread];
	}
}

- (void)startUpdate:(NSString*)localFolder {
	//	NSLog(@"%s: localFolder '%@'", __FUNCTION__, localFolder);
	
	[self cancelUpdate:localFolder];
}

- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");
	
	SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
	
	for(MCOIMAPMessage *imapMessage in imapMessages) {
		NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", collection.messageThreads.count, collection.messageThreadsByDate.count);

		//NSLog(@"%s: looking for imap message with uid %u, gmailThreadId %llu", __FUNCTION__, [imapMessage uid], [imapMessage gmailThreadID]);

		const uint64_t threadId = [imapMessage gmailThreadID];
		NSNumber *threadIdKey = [NSNumber numberWithUnsignedLongLong:threadId];
		SMMessageThread *messageThread = [[collection messageThreads] objectForKey:threadIdKey];

		NSDate *firstMessageDate = nil;
		NSUInteger oldIndex = NSUIntegerMax;
		
		Boolean threadUpdated = NO;

		if(messageThread == nil) {
			messageThread = [[SMMessageThread alloc] initWithThreadId:threadId];
			[[collection messageThreads] setObject:messageThread forKey:threadIdKey];
			
			threadUpdated = YES;
		} else {
			oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];
			NSAssert(oldIndex != NSNotFound, @"message thread not found");
			
			SMMessage *firstMessage = messageThread.messagesSortedByDate.firstObject;
			firstMessageDate = [firstMessage date];
		}

		SMThreadUpdateResult threadUpdateResult = [messageThread updateIMAPMessage:imapMessage remoteFolder:remoteFolderName session:session];
		if(threadUpdateResult != SMThreadUpdateResultNone) {
			if(updateResult == SMMesssageStorageUpdateResultNone) {
				updateResult = (threadUpdateResult == SMThreadUpdateResultStructureChanged? SMMesssageStorageUpdateResultStructureChanged : SMMesssageStorageUpdateResultFlagsChanged);
			} else if(updateResult == SMThreadUpdateResultStructureChanged) {
				updateResult = SMMesssageStorageUpdateResultStructureChanged;
			}
		}

		if(!threadUpdated) {
			SMMessage *firstMessage = messageThread.messagesSortedByDate.firstObject;

			if(firstMessageDate != [firstMessage date])
				threadUpdated = YES;
		}
		
		if(threadUpdated) {
			[self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
			updateResult = SMMesssageStorageUpdateResultStructureChanged;
		}

		NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu (oldIndex %lu, threadUpdated %u, threadUpdateResult %lu)", collection.messageThreads.count, collection.messageThreadsByDate.count, oldIndex, threadUpdated, threadUpdateResult);
	}
	
	return updateResult;
}

- (SMMessageStorageUpdateResult)endUpdate:(NSString*)localFolder removeVanishedMessages:(Boolean)removeVanishedMessages {
//	NSLog(@"%s: localFolder '%@'", __FUNCTION__, localFolder);
	
	SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
	
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad thread collection");
	
	NSMutableArray *vanishedThreads = [[NSMutableArray alloc] init];

	for(NSNumber *threadId in collection.messageThreads) {
		SMMessageThread *messageThread = [collection.messageThreads objectForKey:threadId];
		NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];

		SMThreadUpdateResult threadUpdateResult = [messageThread endUpdate:removeVanishedMessages];

		if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
			NSAssert(oldIndex != NSNotFound, @"message thread not found");
			[self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
			
			updateResult = SMMesssageStorageUpdateResultStructureChanged;
		} else if(threadUpdateResult == SMThreadUpdateResultFlagsChanged && updateResult == SMThreadUpdateResultNone) {
			updateResult = SMMesssageStorageUpdateResultFlagsChanged;
		}
		
		if(messageThread.messagesCount == 0)
			[vanishedThreads addObject:messageThread];
	}

	for(SMMessageThread *messageThread in vanishedThreads) {
		[collection.messageThreadsByDate removeObject:messageThread];
		[collection.messageThreads removeObjectForKey:[NSNumber numberWithUnsignedLongLong:messageThread.threadId]];
	}

	NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", collection.messageThreads.count, collection.messageThreadsByDate.count);
	
	return updateResult;
}

- (void)cancelUpdate:(NSString*)localFolder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad thread collection");
	
	for(NSNumber *threadId in collection.messageThreads) {
		SMMessageThread *thread = [collection.messageThreads objectForKey:threadId];
		[thread cancelUpdate];
	}
}

- (void)markMessageThreadAsUpdated:(uint64_t)threadId localFolder:(NSString*)localFolder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");

	SMMessageThread *messageThread = [[collection messageThreads] objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
	[messageThread markAsUpdated];
}

- (void)setMessageData:(NSData*)data uid:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
	NSAssert(collection, @"bad folder collection");
	
	SMMessageThread *thread = [collection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
	[thread setMessageData:data uid:uid];
}

- (BOOL)messageHasData:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
	SMMessageThread *thread = [self messageThreadById:threadId localFolder:localFolder];
//	NSAssert(thread != nil, @"thread id %lld not found in local folder %@", threadId, localFolder);
    if(thread == nil) {
        NSLog(@"%s: thread id %lld not found in local folder %@", __FUNCTION__, threadId, localFolder);
        return NO;
    }

	return [thread messageHasData:uid];
}

- (NSUInteger)messageThreadsCountInLocalFolder:(NSString*)localFolder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];

	// usually this means that no folders loaded yet
	if(collection == nil)
		return 0;

	return [collection.messageThreads count];
}

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index localFolder:(NSString*)folder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:folder];
	
	NSAssert(collection, @"no thread collection found");
	
	if(index >= [collection.messageThreadsByDate count]) {
		NSLog(@"%s: index %lu is beyond message thread size %lu", __func__, index, [collection.messageThreadsByDate count]);
		return nil;
	}

	return [collection.messageThreadsByDate objectAtIndex:index];
}

- (SMMessageThread*)messageThreadById:(uint64_t)threadId localFolder:(NSString*)folder {
	SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:folder];

	if(collection == nil)
		return nil;

	return [collection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
}

@end
