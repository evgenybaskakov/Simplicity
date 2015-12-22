//
//  SMMessageThread.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
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
    NSMutableOrderedSet *_labels;
}

- (id)initWithThreadId:(uint64_t)threadId {
    self = [super init];
    if(self) {
        _threadId = threadId;
        _threadFlags = ThreadFlagsNone;
        _messageCollection = [MessageCollection new];
        _labels = [ NSMutableOrderedSet new ];
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

- (SMThreadUpdateResult)addMessage:(SMMessage*)message {
    message.updateStatus = SMMessageUpdateStatus_Unknown;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [[[appDelegate model] messageStorage] comparators];

    NSUInteger messageIndex = [_messageCollection.messages indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparator];

    [_messageCollection.messages insertObject:message atIndex:messageIndex];
    
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByDate];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];
    
    [self updateThreadFlagsFromMessage:message];

    return SMThreadUpdateResultStructureChanged;
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
        else if(!message.hasAttachments && [self hasAttachments]) {
            Boolean attachmentFound = NO;
            for(SMMessage *m in _messageCollection.messages) {
                if(m.hasAttachments) {
                    attachmentFound = YES;
                    break;
                }
            }
            if(!attachmentFound) {
                _threadFlags &= ~ThreadFlagsHasAttachment;
                attributesChanged = YES;
            }
        }

        if(message.unseen && ![self unseen]) {
            _threadFlags |= ThreadFlagsUnseen;
            attributesChanged = YES;
        }
        else if(!message.unseen && [self unseen]) {
            Boolean unseenFound = NO;
            for(SMMessage *m in _messageCollection.messages) {
                if(m.unseen) {
                    unseenFound = YES;
                    break;
                }
            }
            if(!unseenFound) {
                _threadFlags &= ~ThreadFlagsUnseen;
                attributesChanged = YES;
            }
        }

        if(message.flagged && ![self flagged]) {
            _threadFlags |= ThreadFlagsFlagged;
            attributesChanged = YES;
        }
        else if(!message.flagged && [self flagged]) {
            Boolean flaggedFound = NO;
            for(SMMessage *m in _messageCollection.messages) {
                if(m.flagged) {
                    flaggedFound = YES;
                    break;
                }
            }
            if(!flaggedFound) {
                _threadFlags &= ~ThreadFlagsFlagged;
                attributesChanged = YES;
            }
        }
    } else {
        SM_LOG_DEBUG(@"message for uid %u not found in current threadId %llu", uid, _threadId);
    }

    return attributesChanged;
}

- (void)setMessageData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments uid:(uint32_t)uid {
    SMMessage *message = [self getMessage:uid];
        
    if(message != nil) {
        NSAssert(message.uid == uid, @"bad message found");
        
        SM_LOG_DEBUG(@"set message data for uid %u", uid);
        
        [message setData:data parser:parser attachments:attachments];
    } else {
        SM_LOG_DEBUG(@"message for uid %u not found in current threadId %llu", uid, _threadId);
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
        
        SM_LOG_DEBUG(@"set message data for uid %u", uid);
        
        hasData = [ message hasData ];
    } else {
        SM_LOG_WARNING(@"message for uid %u not found", uid);
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

    [_labels addObjectsFromArray:message.labels];
}

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session unseenCount:(NSUInteger*)unseenCount {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [[[appDelegate model] messageStorage] comparators];

    SM_LOG_DEBUG(@"looking for imap message with uid %u", [imapMessage uid]);
    
    NSUInteger messageIndex = [_messageCollection.messages indexOfObject:imapMessage inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:[comparators messagesComparatorByImapMessage]];
    
    if(messageIndex < [_messageCollection count]) {
        SMMessage *message = [_messageCollection.messages objectAtIndex:messageIndex];
        
        if([message uid] == [imapMessage uid]) {
            BOOL wasUnseen = message.unseen;
            
            // TODO: can date be changed?
            Boolean hasUpdates = [message updateImapMessage:imapMessage];
            
            message.updateStatus = SMMessageUpdateStatus_Persisted;
            
            BOOL nowUnseen = message.unseen;
            if(wasUnseen != nowUnseen) {
                if(nowUnseen) {
                    (*unseenCount)++;
                }
                else if(*unseenCount > 0) {
                    (*unseenCount)--;
                }
            }
            
            if(hasUpdates) {
                [self updateThreadFlagsFromMessage:message];

                return SMThreadUpdateResultFlagsChanged;
            } else {
                return SMThreadUpdateResultNone;
            }
        }
    }
    
    // update the messages list
    SMMessage *message = [[SMMessage alloc] initWithMCOIMAPMessage:imapMessage remoteFolder:remoteFolderName];

    message.updateStatus = SMMessageUpdateStatus_New;
    
    [_messageCollection.messages insertObject:message atIndex:messageIndex];

    // update the date sorted messages list
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:[comparators messagesComparatorByDate]];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];

    [self updateThreadFlagsFromMessage:message];
    
    if(message.unseen) {
        (*unseenCount)++;
    }
    
    return SMThreadUpdateResultStructureChanged;
}

- (SMThreadUpdateResult)endUpdate:(Boolean)removeVanishedMessages vanishedMessages:(NSMutableArray*)vanishedMessages addNewUnseenMessages:(NSMutableArray *)addNewUnseenMessages {
    NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");
    NSAssert(_messageCollection.messagesByDate.count > 0, @"empty message thread");
    
    SMMessage *firstMessage = [_messageCollection.messagesByDate firstObject];
    NSMutableArray *vanishedMessageUIDs = [NSMutableArray array];

    _unseenMessagesCount = 0;
    
    if(removeVanishedMessages) {
        NSMutableIndexSet *notUpdatedMessageIndices = [NSMutableIndexSet new];
        
        for(NSUInteger i = 0, count = [_messageCollection count]; i < count; i++) {
            SMMessage *message = [_messageCollection.messages objectAtIndex:i];
            
            if(message.updateStatus == SMMessageUpdateStatus_Unknown) {
                SM_LOG_DEBUG(@"thread %llu, message with uid %u vanished", _threadId, message.uid);

                [notUpdatedMessageIndices addIndex:i];

                [vanishedMessages addObject:message];
                [vanishedMessageUIDs addObject:[NSNumber numberWithUnsignedInt:message.uid]];
            }
        }
        
        // remove obsolete messages from the storage
        [_messageCollection.messages removeObjectsAtIndexes:notUpdatedMessageIndices];
        
        // remove obsolete messages from the date sorted messages list
        [notUpdatedMessageIndices removeAllIndexes];
        
        for(NSUInteger i = 0, count = [_messageCollection.messagesByDate count]; i < count; i++) {
            SMMessage *message = [_messageCollection.messagesByDate objectAtIndex:i];
            
            if(message.updateStatus == SMMessageUpdateStatus_Unknown) {
                [notUpdatedMessageIndices addIndex:i];
            }
        }
        
        [_messageCollection.messagesByDate removeObjectsAtIndexes:notUpdatedMessageIndices];

        if(_messageCollection.count == 0)
            SM_LOG_DEBUG(@"thread %llu - all messages vanished", _threadId);
    }
    
    NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");

    SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
    [[[appDelegate model] messageStorage] deleteMessagesFromStorageByUIDs:vanishedMessageUIDs];
    
    const ThreadFlags oldThreadFlags = _threadFlags;
    _threadFlags = ThreadFlagsNone;

    NSMutableOrderedSet *newLabels = [NSMutableOrderedSet new];
    for(SMMessage *message in _messageCollection.messages) {
        [self updateThreadFlagsFromMessage:message];
        
        if(message.unseen) {
            _unseenMessagesCount++;
            
            if(message.updateStatus == SMMessageUpdateStatus_New) {
                [addNewUnseenMessages addObject:message];
            }
        }

        // clear messages update marks for future updates
        message.updateStatus = SMMessageUpdateStatus_Unknown;

        SM_LOG_DEBUG(@"Thread %llu, message labels %@", _threadId, message.labels);
        [newLabels addObjectsFromArray:message.labels];
    }
    
    Boolean labelsChanged = NO;
    if(![_labels isEqualToOrderedSet:newLabels]) {
        _labels = newLabels;
        labelsChanged = YES;
    }

    if(_messageCollection.count == 0)
        return SMThreadUpdateResultStructureChanged;

    SMMessage *newFirstMessage = [_messageCollection.messagesByDate firstObject];
    if(firstMessage.date != newFirstMessage.date)
        return SMThreadUpdateResultStructureChanged;
        
    if(oldThreadFlags != _threadFlags || labelsChanged)
        return SMThreadUpdateResultFlagsChanged;
        
    return SMThreadUpdateResultNone;
}

- (void)cancelUpdate {
    for(SMMessage *message in [_messageCollection messages]) {
        message.updateStatus = SMMessageUpdateStatus_Unknown;
    }
}

- (void)markAsUpdated {
    for(SMMessage *message in [_messageCollection messages]) {
        message.updateStatus = SMMessageUpdateStatus_Persisted;
    }
}

- (void)removeMessageFromMessageThread:(uint32_t)uid {
    NSMutableOrderedSet *messages = [_messageCollection messages];
    for(NSUInteger i = 0, count = messages.count; i < count; i++) {
        SMMessage *message = [messages objectAtIndex:i];
        
        if(message.uid == uid) {
            [messages removeObjectAtIndex:i];
            break;
        }
    }

    messages = [_messageCollection messagesByDate];
    for(NSUInteger i = 0, count = messages.count; i < count; i++) {
        SMMessage *message = [messages objectAtIndex:i];
        
        if(message.uid == uid) {
            [messages removeObjectAtIndex:i];
            break;
        }
    }
    
    NSAssert([_messageCollection messages].count == [_messageCollection messagesByDate].count, @"message storage inconsistency after removing a message");
}

@end
