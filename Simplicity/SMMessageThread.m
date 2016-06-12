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
@property NSMutableOrderedSet *messagesByUID;
@property (readonly) NSUInteger count;
@end

@implementation MessageCollection

- (id)init {
    self = [ super init ];
    
    if(self) {
        _messagesByUID = [ NSMutableOrderedSet new ];
        _messagesByDate = [ NSMutableOrderedSet new ];
    }
    
    return self;
}

- (NSUInteger)count {
    return [_messagesByUID count];
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

    NSNumber *uidNumber = [NSNumber numberWithUnsignedInt:message.uid];
    NSUInteger messageIndex = [_messageCollection.messagesByUID indexOfObject:uidNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByUID];

    SMMessage *existingMessage = messageIndex < _messageCollection.messagesByUID.count? [_messageCollection.messagesByUID objectAtIndex:messageIndex] : nil;
    if(existingMessage != nil && existingMessage.uid == message.uid && existingMessage.threadId == message.threadId) {
        SM_LOG_INFO(@"Message storage already contains message uid %u, threadId %llu", message.uid, message.threadId);
        return SMThreadUpdateResultNone;
    }
    
    [_messageCollection.messagesByUID insertObject:message atIndex:messageIndex];
    
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByDate];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];
    
    [self updateThreadFlagsFromMessage:message];

    return SMThreadUpdateResultStructureChanged;
}

- (SMThreadUpdateResult)removeMessage:(SMMessage*)message {
    BOOL firstMessage = (_messageCollection.messagesByDate.firstObject == message);
    
    [_messageCollection.messagesByUID removeObject:message];
    [_messageCollection.messagesByDate removeObject:message];

    // TODO: update message thread flags if not first message
    
    return firstMessage? SMThreadUpdateResultStructureChanged : SMThreadUpdateResultFlagsChanged;
}

- (SMMessage*)getMessageByUID:(uint32_t)uid {
    SMAppDelegate *appDelegate =  [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    NSNumber *uidNumber = [NSNumber numberWithUnsignedInt:uid];
    NSUInteger messageIndex = [_messageCollection.messagesByUID indexOfObject:uidNumber inSortedRange:NSMakeRange(0, [_messageCollection count]) options:0 usingComparator:comparators.messagesComparatorByUID];
    
    return messageIndex != NSNotFound? [_messageCollection.messagesByUID objectAtIndex:messageIndex] : nil;
}

- (NSInteger)messagesCount {
    return [_messageCollection count];
}

- (NSArray*)messagesSortedByDate {
    return [[_messageCollection messagesByDate] array];
}

- (Boolean)updateThreadAttributesFromMessageUID:(uint32_t)uid {
    SMMessage *message = [self getMessageByUID:uid];
    
    Boolean attributesChanged = NO;
    
    if(message != nil) {
        NSAssert(message.uid == uid, @"bad message found");
        
        if(message.hasAttachments && ![self hasAttachments]) {
            _threadFlags |= ThreadFlagsHasAttachment;
            attributesChanged = YES;
        }
        else if(!message.hasAttachments && [self hasAttachments]) {
            Boolean attachmentFound = NO;
            for(SMMessage *m in _messageCollection.messagesByUID) {
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
            for(SMMessage *m in _messageCollection.messagesByUID) {
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
            for(SMMessage *m in _messageCollection.messagesByUID) {
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
            for(SMMessage *m in _messageCollection.messagesByUID) {
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
        SM_LOG_DEBUG(@"message for uid %u not found in current threadId %llu", uid, _threadId);
    }

    return attributesChanged;
}

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments plainTextBody:(NSString*)plainTextBody uid:(uint32_t)uid {
    SMMessage *message = [self getMessageByUID:uid];
        
    if(message != nil) {
        NSAssert(message.uid == uid, @"bad message found");
        
        SM_LOG_DEBUG(@"set message data for uid %u", uid);
        
        message.msgParser = parser;
        
        if(attachments != nil) {
            message.attachments = attachments;
            message.hasAttachments = (attachments.count != 0? YES : NO);
        }
        
        if(plainTextBody != nil) {
            message.plainTextBody = plainTextBody;
        }
    } else {
        SM_LOG_DEBUG(@"message for uid %u not found in current threadId %llu", uid, _threadId);
    }
    
    return message;
}

- (Boolean)messageHasData:(uint32_t)uid {
    Boolean hasData = NO;
    SMMessage *message = [self getMessageByUID:uid];

    if(message != nil) {
        NSAssert(message.uid == uid, @"bad message found");
        
        SM_LOG_DEBUG(@"set message data for uid %u", uid);
        
        hasData = [ message hasData ];
    } else {
        SM_LOG_DEBUG(@"message for uid %u is not yet contained in thread %lld", uid, _threadId);
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

- (SMThreadUpdateResult)updateIMAPMessage:(MCOIMAPMessage*)imapMessage plainTextBody:(NSString*)plainTextBody remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session unseenCount:(NSUInteger*)unseenCount {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication ] delegate];
    SMMessageComparators *comparators = [appDelegate messageComparators];

    SM_LOG_DEBUG(@"looking for imap message with uid %u", [imapMessage uid]);
    
    NSUInteger messageIndex = [_messageCollection.messagesByUID indexOfObject:imapMessage inSortedRange:NSMakeRange(0, [_messageCollection count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByImapMessage];
    
    if(messageIndex < [_messageCollection count]) {
        SMMessage *message = [_messageCollection.messagesByUID objectAtIndex:messageIndex];
        
        if([message uid] == [imapMessage uid]) {
            if(plainTextBody != nil) {
                message.plainTextBody = plainTextBody;
            }
            
            BOOL wasUnseen = message.unseen;
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

    message.plainTextBody = plainTextBody;
    message.updateStatus = SMMessageUpdateStatus_New;
    
    [_messageCollection.messagesByUID insertObject:message atIndex:messageIndex];

    // update the date sorted messages list
    NSUInteger messageIndexByDate = [_messageCollection.messagesByDate indexOfObject:message inSortedRange:NSMakeRange(0, [_messageCollection.messagesByDate count]) options:NSBinarySearchingInsertionIndex usingComparator:comparators.messagesComparatorByDate];
    
    [_messageCollection.messagesByDate insertObject:message atIndex:messageIndexByDate];

    [self updateThreadFlagsFromMessage:message];
    
    if(message.unseen) {
        (*unseenCount)++;
    }
    
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
    NSMutableArray *vanishedMessageUIDs = [NSMutableArray array];

    _unseenMessagesCount = 0;
    
    if(removeVanishedMessages) {
        NSMutableIndexSet *notUpdatedMessageIndices = [NSMutableIndexSet new];
        
        for(NSUInteger i = 0, count = [_messageCollection count]; i < count; i++) {
            SMMessage *message = [_messageCollection.messagesByUID objectAtIndex:i];
            
            if([self messageOutdated:message]) {
                SM_LOG_DEBUG(@"thread %llu, message with uid %u vanished", _threadId, message.uid);

                [notUpdatedMessageIndices addIndex:i];

                [vanishedMessages addObject:message];
                [vanishedMessageUIDs addObject:[NSNumber numberWithUnsignedInt:message.uid]];
            }
        }
        
        // remove obsolete messages from the storage
        [_messageCollection.messagesByUID removeObjectsAtIndexes:notUpdatedMessageIndices];
        
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

    [_messageStorage deleteMessagesFromStorageByUIDs:vanishedMessageUIDs];
    
    const ThreadFlags oldThreadFlags = _threadFlags;
    _threadFlags = ThreadFlagsNone;

    NSMutableOrderedSet *newLabels = [NSMutableOrderedSet new];
    for(SMMessage *message in _messageCollection.messagesByUID) {
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
    for(SMMessage *message in [_messageCollection messagesByUID]) {
        message.updateStatus = SMMessageUpdateStatus_Unknown;
    }
}

- (void)markAsUpdated {
    for(SMMessage *message in [_messageCollection messagesByUID]) {
        message.updateStatus = SMMessageUpdateStatus_Persisted;
    }
}

- (void)removeMessageFromMessageThread:(uint32_t)uid {
    NSMutableOrderedSet *messages = [_messageCollection messagesByUID];
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
    
    NSAssert([_messageCollection messagesByUID].count == [_messageCollection messagesByDate].count, @"message storage inconsistency after removing a message");
}

@end
