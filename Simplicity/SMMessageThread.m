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
#import "SMOutgoingMessage.h"
#import "SMAppDelegate.h"
#import "SMMessageComparators.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"

@interface MessageCollection : NSObject
@property NSMutableOrderedSet *messagesByDate;
@property NSMutableOrderedSet *messagesByMessageId;
@property (readonly) NSUInteger count;
@end

@implementation MessageCollection

- (id)init {
    self = [ super init ];
    
    if(self) {
        _messagesByMessageId = [ NSMutableOrderedSet new ];
        _messagesByDate = [ NSMutableOrderedSet new ];
    }
    
    return self;
}

- (NSUInteger)count {
    return [_messagesByMessageId count];
}

@end

typedef NS_OPTIONS(NSUInteger, ThreadFlags) {
    ThreadFlagsNone           = 0,
    ThreadFlagsUnseen         = 1 << 0,
    ThreadFlagsFlagged        = 1 << 1,
    ThreadFlagsHasAttachment  = 1 << 2,
    ThreadFlagsHasPreview     = 1 << 3,
    ThreadFlagsHasDraft       = 1 << 4,
};

@implementation SMMessageThread {
    uint64_t _threadId;
    ThreadFlags _threadFlags;
    MessageCollection *_messageCollection;
    NSMutableOrderedSet *_labels;
    NSString *_cachedBodyPreview;
}

- (id)initWithThreadId:(uint64_t)threadId messageStorage:(SMMessageStorage*)messageStorage {
    self = [super init];
    if(self) {
        _threadId = threadId;
        _threadFlags = ThreadFlagsNone;
        _messageStorage = messageStorage;
        _messageCollection = [[MessageCollection alloc] init];
        _labels = [[NSMutableOrderedSet alloc] init];
    }
    return self;
}

- (SMUserAccount*)account {
    SMMessageStorage *messageStorage = _messageStorage;
    if(messageStorage == nil) {
        return nil;
    }
    
    NSAssert([(NSObject*)messageStorage.account isKindOfClass:[SMUserAccount class]], @"bad account type in this message thread's message storage");
    return (SMUserAccount*)messageStorage.account;
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

- (Boolean)hasDraft {
    return _threadFlags & ThreadFlagsHasDraft;
}

- (Boolean)hasPreview {
    return _threadFlags & ThreadFlagsHasPreview;
}

- (SMThreadUpdateResult)addMessage:(SMMessage*)message {
    message.updateStatus = SMMessageUpdateStatus_Unknown;
    
    SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    NSNumber *messageIdNumber = [NSNumber numberWithUnsignedLongLong:message.messageId];
    NSUInteger messageIndex = [_messageCollection.messagesByMessageId indexOfObject:messageIdNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByMessageId];

    SMMessage *existingMessage = messageIndex < _messageCollection.messagesByMessageId.count? [_messageCollection.messagesByMessageId objectAtIndex:messageIndex] : nil;
    if(existingMessage != nil && existingMessage.messageId == message.messageId && existingMessage.threadId == message.threadId) {
        SM_LOG_INFO(@"Message storage already contains message id %llu, threadId %llu", message.messageId, message.threadId);
        return SMThreadUpdateResultNone;
    }
    
    [_messageCollection.messagesByMessageId insertObject:message atIndex:messageIndex];
    
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByDate];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];
    
    [self updateThreadFlagsFromMessage:message];

    return SMThreadUpdateResultStructureChanged;
}

- (SMThreadUpdateResult)removeMessage:(SMMessage*)message {
    BOOL firstMessage = (_messageCollection.messagesByDate.firstObject == message);
    
    [_messageCollection.messagesByMessageId removeObject:message];
    [_messageCollection.messagesByDate removeObject:message];

    // TODO: update message thread flags if not first message
    
    return firstMessage? SMThreadUpdateResultStructureChanged : SMThreadUpdateResultFlagsChanged;
}

- (SMMessage*)getMessageByMessageId:(uint64_t)messageId {
    SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    NSNumber *messageIdNumber = [NSNumber numberWithUnsignedLongLong:messageId];
    NSUInteger messageIndex = [_messageCollection.messagesByMessageId indexOfObject:messageIdNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:0 usingComparator:comparators.messagesComparatorByMessageId];
    
    return messageIndex != NSNotFound? [_messageCollection.messagesByMessageId objectAtIndex:messageIndex] : nil;
}

- (NSInteger)messagesCount {
    return [_messageCollection count];
}

- (NSArray*)messagesSortedByDate {
    return [[_messageCollection messagesByDate] array];
}

- (Boolean)updateThreadAttributesForMessageId:(uint64_t)messageId {
    SMMessage *message = [self getMessageByMessageId:messageId];
    
    Boolean attributesChanged = NO;
    
    if(message != nil) {
        NSAssert(message.messageId == messageId, @"bad message found");
        
        if(message.hasAttachments && ![self hasAttachments]) {
            _threadFlags |= ThreadFlagsHasAttachment;
            attributesChanged = YES;
        }
        else if(!message.hasAttachments && [self hasAttachments]) {
            Boolean attachmentFound = NO;
            for(SMMessage *m in _messageCollection.messagesByMessageId) {
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

        if(message.draft && ![self hasDraft]) {
            _threadFlags |= ThreadFlagsHasDraft;
            attributesChanged = YES;
        }
        else if(!message.draft && [self hasDraft]) {
            Boolean draftFound = NO;
            for(SMMessage *m in _messageCollection.messagesByMessageId) {
                if(m.draft) {
                    draftFound = YES;
                    break;
                }
            }
            if(!draftFound) {
                _threadFlags &= ~ThreadFlagsHasDraft;
                attributesChanged = YES;
            }
        }
        
        if(message.unseen && ![self unseen]) {
            _threadFlags |= ThreadFlagsUnseen;
            attributesChanged = YES;
        }
        else if(!message.unseen && [self unseen]) {
            Boolean unseenFound = NO;
            for(SMMessage *m in _messageCollection.messagesByMessageId) {
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
            for(SMMessage *m in _messageCollection.messagesByMessageId) {
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
        
        if(message == self.messagesSortedByDate.firstObject) {
            NSString *bodyPreview = message.plainTextBody;
            
            if(bodyPreview != nil && ![self hasPreview]) {
                _threadFlags |= ThreadFlagsHasPreview;
                _cachedBodyPreview = bodyPreview;

                attributesChanged = YES;
            }
            else if(bodyPreview == nil && [self hasPreview]) {
                _threadFlags &= ~ThreadFlagsHasPreview;
                _cachedBodyPreview = nil;
                
                attributesChanged = YES;
            }
            else if(bodyPreview != nil && bodyPreview != _cachedBodyPreview) {
                _cachedBodyPreview = bodyPreview;
                
                attributesChanged = YES;
            }
        }
    } else {
        SM_LOG_DEBUG(@"message for id %llu not found in current threadId %llu", messageId, _threadId);
    }

    return attributesChanged;
}

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody messageId:(uint64_t)messageId {
    SMMessage *message = [self getMessageByMessageId:messageId];
        
    if(message != nil) {
        NSAssert(message.messageId == messageId, @"bad message found (message.messageId %llu, messageId %llu)", message.messageId, messageId);
        
        SM_LOG_DEBUG(@"set message data for id %llu", messageId);
        
        if(parser != nil) {
            message.msgParser = parser;
        }
        
        if(attachments != nil) {
            message.attachments = attachments;
            message.hasAttachments = (attachments.count != 0? YES : NO);
        }
        else {
            message.hasAttachments = hasAttachments;
        }
        
        if(plainTextBody != nil) {
            message.plainTextBody = plainTextBody;
        }
    } else {
        SM_LOG_DEBUG(@"message for id %llu not found in current threadId %llu", messageId, _threadId);
    }
    
    return message;
}

- (Boolean)messageHasData:(uint64_t)messageId {
    Boolean hasData = NO;
    SMMessage *message = [self getMessageByMessageId:messageId];

    if(message != nil) {
        NSAssert(message.messageId == messageId, @"bad message found");
        
        SM_LOG_DEBUG(@"set message data for id %llu", messageId);
        
        hasData = [ message hasData ];
    }
    else {
        SM_LOG_DEBUG(@"message for id %llu is not yet contained in thread %lld", messageId, _threadId);
    }
    
    return hasData;
}

- (SMMessage*)messageAtIndexByDate:(NSUInteger)index {
    SMMessage *const message = (index < [_messageCollection.messagesByDate count]? [ _messageCollection.messagesByDate objectAtIndex:index ] : nil);
    
    return message;
}

- (void)updateThreadFlagsFromMessage:(SMMessage*)message {
    if(message.unseen) {
        _threadFlags |= ThreadFlagsUnseen;
    }

    if(message.flagged) {
        _threadFlags |= ThreadFlagsFlagged;
    }
    
    if(message.hasAttachments) {
        _threadFlags |= ThreadFlagsHasAttachment;
    }
    
    if(message.draft) {
        _threadFlags |= ThreadFlagsHasDraft;
    }

    [_labels addObjectsFromArray:message.labels];
}

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage plainTextBody:(NSString*)plainTextBody hasAttachments:(BOOL)hasAttachments remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session unseenCount:(NSUInteger*)unseenCount messageIsNew:(BOOL*)messageIsNew {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    SM_LOG_DEBUG(@"looking for imap message with id %llu", imapMessage.gmailMessageID);
    
    NSUInteger messageIndex = [_messageCollection.messagesByMessageId indexOfObject:imapMessage inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByImapMessage];
    
    if(messageIndex < [_messageCollection count]) {
        SMMessage *message = [_messageCollection.messagesByMessageId objectAtIndex:messageIndex];
        
        if(message.messageId == imapMessage.gmailMessageID) {
            if(plainTextBody != nil) {
                message.plainTextBody = plainTextBody;
            }
            
            BOOL wasUnseen = message.unseen;
            Boolean hasUpdates = [message updateImapMessage:imapMessage];
            
            message.updateStatus = SMMessageUpdateStatus_Persisted;
            
            BOOL nowUnseen = message.unseen;
            if(wasUnseen != nowUnseen && unseenCount != nil) {
                if(nowUnseen) {
                    (*unseenCount)++;
                }
                else if(*unseenCount > 0) {
                    (*unseenCount)--;
                }
            }
            
            *messageIsNew = NO;
            
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

    message.plainTextBody = plainTextBody;
    message.hasAttachments = hasAttachments;
    message.updateStatus = SMMessageUpdateStatus_New;
    
    [_messageCollection.messagesByMessageId insertObject:message atIndex:messageIndex];

    // update the date sorted messages list
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByDate];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];

    [self updateThreadFlagsFromMessage:message];
    
    if(message.unseen && unseenCount != nil) {
        (*unseenCount)++;
    }
    
    *messageIsNew = YES;
    
    return SMThreadUpdateResultStructureChanged;
}

- (BOOL)messageOutdated:(SMMessage*)message {
    // Never consider "outgoing" messages as outdated, because they're always local.
    return ![message isKindOfClass:[SMOutgoingMessage class]] && message.updateStatus == SMMessageUpdateStatus_Unknown;
}

- (SMThreadUpdateResult)endUpdate:(Boolean)removeVanishedMessages vanishedMessages:(NSMutableArray*)vanishedMessages addNewUnseenMessages:(NSMutableArray *)addNewUnseenMessages {
    NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");
    NSAssert(_messageCollection.messagesByDate.count > 0, @"empty message thread");
    
    SMMessage *firstMessage = [_messageCollection.messagesByDate firstObject];
    NSMutableArray<NSNumber*> *vanishedMessageIds = [NSMutableArray array];

    _unseenMessagesCount = 0;
    
    if(removeVanishedMessages) {
        NSMutableIndexSet *notUpdatedMessageIndices = [NSMutableIndexSet new];
        
        for(NSUInteger i = 0, count = [_messageCollection count]; i < count; i++) {
            SMMessage *message = [_messageCollection.messagesByMessageId objectAtIndex:i];
            
            if([self messageOutdated:message]) {
                SM_LOG_DEBUG(@"thread %llu, message with id %llu vanished", _threadId, message.messageId);

                [notUpdatedMessageIndices addIndex:i];

                [vanishedMessages addObject:message];
                [vanishedMessageIds addObject:[NSNumber numberWithUnsignedLongLong:message.messageId]];
            }
        }
        
        // remove obsolete messages from the storage
        [_messageCollection.messagesByMessageId removeObjectsAtIndexes:notUpdatedMessageIndices];
        
        // remove obsolete messages from the date sorted messages list
        [notUpdatedMessageIndices removeAllIndexes];
        
        for(NSUInteger i = 0, count = [_messageCollection.messagesByDate count]; i < count; i++) {
            SMMessage *message = [_messageCollection.messagesByDate objectAtIndex:i];
            
            if([self messageOutdated:message]) {
                [notUpdatedMessageIndices addIndex:i];
            }
        }
        
        [_messageCollection.messagesByDate removeObjectsAtIndexes:notUpdatedMessageIndices];

        if(_messageCollection.count == 0) {
            SM_LOG_DEBUG(@"thread %llu - all messages vanished", _threadId);
        }
    }
    
    NSAssert([_messageCollection count] == [_messageCollection.messagesByDate count], @"message lists mismatch");

    [_messageStorage deleteMessagesFromStorageByMessageIds:vanishedMessageIds];
    
    const ThreadFlags oldThreadFlags = _threadFlags;
    _threadFlags = ThreadFlagsNone;

    NSMutableOrderedSet *newLabels = [NSMutableOrderedSet new];
    for(SMMessage *message in _messageCollection.messagesByMessageId) {
        [self updateThreadFlagsFromMessage:message];
        
        if(message.unseen) {
            _unseenMessagesCount++;
            
            if(message.updateStatus == SMMessageUpdateStatus_New) {
                [addNewUnseenMessages addObject:message];
            }
        }

        // clear messages update marks for future updates
        message.updateStatus = SMMessageUpdateStatus_Unknown;

        SM_LOG_NOISE(@"Thread %llu, message labels %@", _threadId, message.labels);
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
    for(SMMessage *message in [_messageCollection messagesByMessageId]) {
        message.updateStatus = SMMessageUpdateStatus_Unknown;
    }
}

- (void)markAsUpdated {
    for(SMMessage *message in [_messageCollection messagesByMessageId]) {
        message.updateStatus = SMMessageUpdateStatus_Persisted;
    }
}

- (void)removeMessageFromMessageThread:(uint64_t)messageId {
    SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    NSNumber *messageIdNumber = [NSNumber numberWithUnsignedLongLong:messageId];
    NSUInteger messageIndex = [_messageCollection.messagesByMessageId indexOfObject:messageIdNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:0 usingComparator:comparators.messagesComparatorByMessageId];
    
    if(messageIndex != NSNotFound) {
        [_messageCollection.messagesByMessageId removeObjectAtIndex:messageIndex];
    }
    
    NSMutableOrderedSet *messagesByDate = [_messageCollection messagesByDate];
    for(NSUInteger i = 0, count = messagesByDate.count; i < count; i++) {
        SMMessage *message = [messagesByDate objectAtIndex:i];
        
        if(message.messageId == messageId) {
            [messagesByDate removeObjectAtIndex:i];
            break;
        }
    }
    
    NSAssert([_messageCollection messagesByMessageId].count == [_messageCollection messagesByDate].count, @"message storage inconsistency after removing a message");
}

@end
