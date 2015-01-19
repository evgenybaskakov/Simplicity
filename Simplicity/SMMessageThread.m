//
//  SMMessageThread.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMMessage.h"
#import "SMAppDelegate.h"
#import "SMMessageComparators.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"

@interface MessageCollection : NSObject
@property NSMutableOrderedSet *messagesByDate;
@property NSMutableOrderedSet *messages;
@property (readonly) NSUInteger count;
@end

@implementation MessageCollection

- (id)init {
	self = [ super init ];
	
	if(self) {
		_messages = [ NSMutableOrderedSet new ];
		_messagesByDate = [ NSMutableOrderedSet new ];
	}
	
	return self;
}

- (NSUInteger)count {
	return [_messages count];
}

@end

typedef NS_OPTIONS(NSUInteger, ThreadFlags) {
	ThreadFlagsNone           = 0,
	ThreadFlagsUnseen         = 1 << 0,
	ThreadFlagsFlagged        = 1 << 1,
	ThreadFlagsHasAttachment  = 1 << 2,
};

@implementation SMMessageThread {
	uint64_t _threadId;
	ThreadFlags _threadFlags;
	MessageCollection *_messageCollection;
}

- (id)initWithThreadId:(uint64_t)threadId {
	self = [super init];
	if(self) {
		_threadId = threadId;
		_threadFlags = ThreadFlagsNone;
		_messageCollection = [MessageCollection new];
	}
	return self;
}

- (uint64_t)threadId {
	return _threadId;
}

- (Boolean)unseen {
	return _threadFlags & ThreadFlagsUnseen;
}

- (Boolean)flagged {
	return _threadFlags & ThreadFlagsFlagged;
}

- (Boolean)hasAttachments {
	return _threadFlags & ThreadFlagsHasAttachment;
}

- (SMMessage*)latestMessage {
	NSAssert(0, @"TODO");
	return nil;
}

- (SMMessage*)getMessage:(uint32_t)uid {
	SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
	SMMessageComparators *comparators = [[[appDelegate model] messageStorage] comparators];

	NSNumber *uidNumber = [NSNumber numberWithUnsignedInt:uid];
	NSUInteger messageIndex = [_messageCollection.messages indexOfObject:uidNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:0 usingComparator:comparators.messagesComparatorByUID];
	
	return messageIndex != NSNotFound? [_messageCollection.messages objectAtIndex:messageIndex] : nil;
}

- (NSInteger)messagesCount {
	return [_messageCollection count];
}

- (NSArray*)messagesSortedByDate {
	return [[_messageCollection messagesByDate] array];
}

- (Boolean)updateThreadAttributesFromMessageUID:(uint32_t)uid {
	SMMessage *message = [self getMessage:uid];
	
	Boolean attributesChanged = NO;
	
	if(message != nil) {
		NSAssert(message.uid == uid, @"bad message found");
		
		if(message.hasAttachments && ![self hasAttachments]) {
			_threadFlags |= ThreadFlagsHasAttachment;
			attributesChanged = YES;
		}
		
	} else {
		NSLog(@"%s: message for uid %u not found in current threadId %llu", __FUNCTION__, uid, _threadId);
	}

	return attributesChanged;
}

- (void)setMessageData:(NSData*)data uid:(uint32_t)uid {
	SMMessage *message = [self getMessage:uid];
		
	if(message != nil) {
		NSAssert(message.uid == uid, @"bad message found");
		
//		NSLog(@"%s: set message data for uid %u", __FUNCTION__, uid);
		
		[ message setData:data ];
	} else {
		NSLog(@"%s: message for uid %u not found in current threadId %llu", __FUNCTION__, uid, _threadId);
	}
}

- (Boolean)messageHasData:(uint32_t)uid {
	Boolean hasData = NO;
	
	SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
	SMMessageComparators *comparators = [[[appDelegate model] messageStorage] comparators];

	NSNumber *uidNumber = [NSNumber numberWithUnsignedInt:uid];
	NSUInteger messageIndex = [_messageCollection.messages indexOfObject:uidNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:0 usingComparator:[comparators messagesComparatorByUID]];
	
	if(messageIndex != NSNotFound) {
		SMMessage *message = [_messageCollection.messages objectAtIndex:messageIndex];
		
		NSAssert(message.uid == uid, @"bad message found");
		
//		NSLog(@"%s: set message data for uid %u", __FUNCTION__, uid);
		
		hasData = [ message hasData ];
	} else {
		NSLog(@"%s: message for uid %u not found", __FUNCTION__, uid);
	}
	
	return hasData;
}

- (SMMessage*)messageAtIndexByDate:(NSUInteger)index {
	SMMessage *const message = (index < [_messageCollection.messagesByDate count]? [ _messageCollection.messagesByDate objectAtIndex:index ] : nil);
	
	return message;
}

- (void)updateThreadFlagsFromMessage:(SMMessage*)message {
	if(message.unseen)
		_threadFlags |= ThreadFlagsUnseen;

	if(message.flagged)
		_threadFlags |= ThreadFlagsFlagged;
	
	if(message.hasAttachments)
		_threadFlags |= ThreadFlagsHasAttachment;
}

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage remoteFolder:(NSString*)remoteFolder session:(MCOIMAPSession*)session {
	SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
	SMMessageComparators *comparators = [[[appDelegate model] messageStorage] comparators];

//	NSLog(@"%s: looking for imap message with uid %u", __FUNCTION__, [imapMessage uid]);
	
	NSUInteger messageIndex = [_messageCollection.messages indexOfObject:imapMessage inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:[comparators messagesComparatorByImapMessage]];
	
	if(messageIndex < [_messageCollection count]) {
		SMMessage *message = [_messageCollection.messages objectAtIndex:messageIndex];
		
		if([message uid] == [imapMessage uid]) {
			// TODO: can date be changed?
			Boolean hasUpdates = [message updateImapMessage:imapMessage];
			
			[message setUpdated:YES];
			
			if(hasUpdates) {
				[self updateThreadFlagsFromMessage:message];

				return SMThreadUpdateResultFlagsChanged;
			} else {
				return SMThreadUpdateResultNone;
			}
			
		}
	}
	
	// update the messages list
	SMMessage *message = [[SMMessage alloc] initWithMCOIMAPMessage:imapMessage remoteFolder:remoteFolder];

	[ message setUpdated:YES];
	
	[ _messageCollection.messages insertObject:message atIndex:messageIndex ];

	// update the date sorted messages list
	NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:[comparators messagesComparatorByDate]];
	
	[ _messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate ];

	[self updateThreadFlagsFromMessage:message];
	
	return SMThreadUpdateResultStructureChanged;
}

- (SMThreadUpdateResult)endUpdate:(Boolean)removeVanishedMessages {
	NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");
	NSAssert(_messageCollection.messagesByDate.count > 0, @"empty message thread");
	
	SMMessage *firstMessage = [_messageCollection.messagesByDate firstObject];

	if(removeVanishedMessages) {
		NSMutableIndexSet *notUpdatedMessageIndices = [NSMutableIndexSet new];
		
		for(NSUInteger i = 0, count = [_messageCollection count]; i < count; i++) {
			SMMessage *message = [_messageCollection.messages objectAtIndex:i];
			
			if(![message updated]) {
				NSLog(@"%s: uid %u - message vanished", __FUNCTION__, [message uid]);
				
				[notUpdatedMessageIndices addIndex:i];
			}
		}
		
		// remove obsolete messages from the storage
		[_messageCollection.messages removeObjectsAtIndexes:notUpdatedMessageIndices];
		
		// remove obsolete messages from the date sorted messages list
		[notUpdatedMessageIndices removeAllIndexes];
		
		for(NSUInteger i = 0, count = [_messageCollection.messagesByDate count]; i < count; i++) {
			SMMessage *message = [_messageCollection.messagesByDate objectAtIndex:i];
			
			if(![message updated])
				[notUpdatedMessageIndices addIndex:i];
		}
		
		[_messageCollection.messagesByDate removeObjectsAtIndexes:notUpdatedMessageIndices];
	}
	
	NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");

	const ThreadFlags oldThreadFlags = _threadFlags;
	_threadFlags = ThreadFlagsNone;

	for(SMMessage *message in _messageCollection.messages) {
		[self updateThreadFlagsFromMessage:message];

		// clear messages update marks for future updates
		[message setUpdated:NO];
	}

	if([_messageCollection count] == 0)
		return SMThreadUpdateResultStructureChanged;

	SMMessage *newFirstMessage = [_messageCollection.messagesByDate firstObject];
	if(firstMessage.date != newFirstMessage.date)
		return SMThreadUpdateResultStructureChanged;
		
	if(oldThreadFlags != _threadFlags)
		return SMThreadUpdateResultFlagsChanged;
		
	return SMThreadUpdateResultNone;
}

- (void)cancelUpdate {
	for(SMMessage *message in [_messageCollection messages])
		[message setUpdated:NO];
}

@end
