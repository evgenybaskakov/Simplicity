//
//  SM_messagestorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMDatabase.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMessageComparators.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadCollection.h"
#import "SMUnifiedMessageStorage.h"
#import "SMAbstractLocalFolder.h"
#import "SMAppDelegate.h"

@implementation SMMessageStorage {
    NSMutableDictionary *_messagesThreadsMap;
    SMMessageThreadCollection *_messageThreadCollection;
    NSMutableIndexSet *_messagesWithUnfinishedDeletion;
    NSMutableIndexSet *_messagesWithUnfinishedUpdate;
    __weak SMUnifiedMessageStorage *_unifiedMessageStorage;
}

@synthesize localFolder = _localFolder;
@synthesize messageThreadsCount = _messageThreadsCount;

- (id)initWithUserAccount:(SMUserAccount *)account localFolder:(id<SMAbstractLocalFolder>)localFolder {
    self = [super initWithUserAccount:account];

    if(self) {
        _localFolder = localFolder;
        _messagesThreadsMap = [NSMutableDictionary new];
        _messageThreadCollection = [SMMessageThreadCollection new];
        _messagesWithUnfinishedDeletion = [NSMutableIndexSet new];
        _messagesWithUnfinishedUpdate = [NSMutableIndexSet new];
    }

    return self;
}

- (void)attachToUnifiedMessageStorage:(SMUnifiedMessageStorage*)unifiedMessageStorage {
    NSAssert(_unifiedMessageStorage == nil, @"already attached to a unified message storage");
    
    _unifiedMessageStorage = unifiedMessageStorage;
    
    for(NSNumber *threadId in _messageThreadCollection.messageThreads) {
        SMMessageThread *messageThread = [_messageThreadCollection.messageThreads objectForKey:threadId];

        [_unifiedMessageStorage addMessageThread:messageThread];
    }
}

- (void)deattachFromUnifiedMessageStorage {
    for(NSNumber *threadId in _messageThreadCollection.messageThreads) {
        SMMessageThread *messageThread = [_messageThreadCollection.messageThreads objectForKey:threadId];
        
        [_unifiedMessageStorage removeMessageThread:messageThread];
    }
    
    _unifiedMessageStorage = nil;
}

- (NSUInteger)messageThreadsCount {
    return _messageThreadCollection.messageThreads.count;
}

- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSComparator messageThreadComparator = [[appDelegate messageComparators] messageThreadsComparatorByDate];

    NSMutableOrderedSet *sortedMessageThreads = _messageThreadCollection.messageThreadsByDate;

    if([_messageThreadCollection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:[messageThread threadId]]] != nil) {
        NSUInteger idx = [sortedMessageThreads indexOfObject:messageThread inSortedRange:NSMakeRange(0, sortedMessageThreads.count) options:NSBinarySearchingFirstEqual usingComparator:messageThreadComparator];
        
        NSAssert([sortedMessageThreads objectAtIndex:idx] == messageThread, @"message threads not the same object");

        return idx;
    } else {
        return NSNotFound;
    }
}

- (void)insertMessageThreadByDate:(SMMessageThread*)messageThread oldIndex:(NSUInteger)oldIndex {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSComparator messageThreadComparator = [[appDelegate messageComparators] messageThreadsComparatorByDate];

    NSMutableOrderedSet *sortedMessageThreads = _messageThreadCollection.messageThreadsByDate;

    if(oldIndex != NSNotFound) {
        NSAssert(_messageThreadCollection.messageThreadsByDate.count == _messageThreadCollection.messageThreads.count, @"message thread counts (sorted %lu, unsorted %lu) don't match", _messageThreadCollection.messageThreadsByDate.count, _messageThreadCollection.messageThreads.count);

        SMMessageThread *oldMessageThread = sortedMessageThreads[oldIndex];
        NSAssert(oldMessageThread == messageThread, @"bad message thread at index %lu (actual id %llu, expected id %llu)", oldIndex, oldMessageThread.threadId, messageThread.threadId);

        [sortedMessageThreads removeObjectAtIndex:oldIndex];

        // Update the unified storage, if any.
        [_unifiedMessageStorage removeMessageThread:messageThread];
    }
    
    NSUInteger messageThreadIndexByDate = [sortedMessageThreads indexOfObject:messageThread inSortedRange:NSMakeRange(0, sortedMessageThreads.count) options:NSBinarySearchingInsertionIndex usingComparator:messageThreadComparator];
    
    NSAssert(messageThreadIndexByDate != NSNotFound, @"message thread not found");
    
    [sortedMessageThreads insertObject:messageThread atIndex:messageThreadIndexByDate];
    
    // Update the unified storage, if any.
    [_unifiedMessageStorage addMessageThread:messageThread];

    // Update thread id map.
    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:messageThread.threadId];
    for(SMMessage *m in messageThread.messagesSortedByDate) {
        [_messagesThreadsMap setObject:threadIdNum forKey:[NSNumber numberWithUnsignedLongLong:m.messageId]];
    }
}

- (void)updateMessageInStorage:(SMMessage *)message folder:(NSString*)folderName {
    NSAssert(sizeof(NSUInteger) == sizeof(message.messageId), @"sizes of NSUInteger and SMMessage.messageId do not match");
    [_messagesWithUnfinishedUpdate addIndex:message.messageId];

    [[_account database] updateMessageInDBFolder:message.imapMessage folder:folderName];
}

- (NSNumber*)messageThreadByMessageId:(uint64_t)messageId {
    return [_messagesThreadsMap objectForKey:[NSNumber numberWithUnsignedLongLong:messageId]];
}

- (void)deleteMessageThread:(SMMessageThread*)messageThread updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    for(SMMessage *m in messageThread.messagesSortedByDate) {
        if(m.unseen && unseenMessagesCount != nil && *unseenMessagesCount > 0) {
            (*unseenMessagesCount)--;
        }

        [_messagesThreadsMap removeObjectForKey:[NSNumber numberWithUnsignedLongLong:m.messageId]];
        
        NSAssert(sizeof(NSUInteger) == sizeof(m.messageId), @"sizes of NSUInteger and SMMessage.messageId do not match");
        [_messagesWithUnfinishedDeletion addIndex:m.messageId];

        SM_LOG_INFO(@"add message id: %llu, total %lu", m.messageId, _messagesWithUnfinishedDeletion.count);
    }

    [_messageThreadCollection.messageThreads removeObjectForKey:[NSNumber numberWithUnsignedLongLong:messageThread.threadId]];
    [_messageThreadCollection.messageThreadsByDate removeObject:messageThread];
    
    // Update the unified storage, if any.
    [_unifiedMessageStorage removeMessageThread:messageThread];
}

- (BOOL)deleteMessageFromStorage:(uint64_t)messageId threadId:(uint64_t)threadId remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    [_messagesThreadsMap removeObjectForKey:[NSNumber numberWithUnsignedLongLong:messageId]];
    
    SMMessageThread *messageThread = [self messageThreadById:threadId];
    NSAssert(messageThread != nil, @"message thread not found for message id %llu, threadId %llu", messageId, threadId);
    NSAssert([messageThread getMessageByMessageId:messageId] != nil, @"message id %llu not found in thread with threadId %llu", messageId, threadId);

    if(messageThread.messagesCount == 1) {
        [self deleteMessageThread:messageThread updateDatabase:YES unseenMessagesCount:unseenMessagesCount];
        return true;
    }
    else {
        NSAssert(sizeof(NSUInteger) == sizeof(messageId), @"sizes of NSUInteger and messageId do not match");
        [_messagesWithUnfinishedDeletion addIndex:messageId];

        SM_LOG_INFO(@"add message id: %llu, total %lu", messageId, _messagesWithUnfinishedDeletion.count);

        SMMessage *message = [messageThread getMessageByMessageId:messageId];
        if(message != nil) {
            if(message.unseen && unseenMessagesCount != nil && *unseenMessagesCount > 0) {
                (*unseenMessagesCount)--;
            }
        }
        
        SMMessage *firstMessage = [messageThread.messagesSortedByDate objectAtIndex:0];
        if(firstMessage == message) {
            NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread];
            
            [messageThread removeMessageFromMessageThread:messageId];
            
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            [self insertMessageThreadByDate:messageThread oldIndex:oldIndex];
            
            return true;
        }
        else {
            [messageThread removeMessageFromMessageThread:messageId];
            return false;
        }
    }
}

- (void)deleteMessagesFromStorageByMessageIds:(NSArray<NSNumber*>*)messageIds {
    [_messagesThreadsMap removeObjectsForKeys:messageIds];
    
    for(NSNumber *messageIdNumber in messageIds) {
        uint64_t messageId = messageIdNumber.unsignedLongLongValue;

        NSAssert(sizeof(NSUInteger) == sizeof(messageId), @"sizes of NSUInteger and messageId do not match");
        [_messagesWithUnfinishedDeletion addIndex:messageId];

        SM_LOG_INFO(@"add message id: %llu, total %lu", messageId, _messagesWithUnfinishedDeletion.count);
    }
}

- (void)completeUpdateForMessage:(SMMessage*)message {
    NSAssert(sizeof(NSUInteger) == sizeof(uint64), @"sizes of NSUInteger and uint64 (messageId) do not match");
    [_messagesWithUnfinishedUpdate removeIndex:message.messageId];
    
    if(_messagesWithUnfinishedUpdate.count > 0)
        SM_LOG_INFO(@"remaining mesage ids %lu", _messagesWithUnfinishedUpdate.count);
}

- (void)completeDeletionForMessages:(NSIndexSet*)messageIds {
    for(NSUInteger i = [messageIds firstIndex]; i != NSNotFound; i = [messageIds indexGreaterThanIndex:i]) {
        SM_LOG_INFO(@"remove message id: %lu", i);
    }
    
    NSAssert(sizeof(NSUInteger) == sizeof(uint64), @"sizes of NSUInteger and uint64 (messageId) do not match");
    [_messagesWithUnfinishedDeletion removeIndexes:messageIds];

    if(_messagesWithUnfinishedDeletion.count > 0)
        SM_LOG_INFO(@"remaining mesage ids %lu", _messagesWithUnfinishedDeletion.count);
}

- (void)startUpdate {
    [self cancelUpdate];
}

- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount newMessages:(NSMutableArray<MCOIMAPMessage*>*)newMessages {
    SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
    
    NSAssert(plainTextBodies == nil || plainTextBodies.count == imapMessages.count, @"plainTextBodies.count %lu, imapMessages.count %lu", plainTextBodies.count, imapMessages.count);
    NSAssert(plainTextBodies == nil || plainTextBodies.count == hasAttachmentsFlags.count, @"plainTextBodies.count %lu, hasAttachmentsFlags.count %lu", plainTextBodies.count, hasAttachmentsFlags.count);
    
    for(NSUInteger i = 0; i < imapMessages.count; i++) {
        MCOIMAPMessage *imapMessage = imapMessages[i];
        
        NSAssert(sizeof(NSUInteger) == sizeof(imapMessage.gmailMessageID), @"sizes of NSUInteger and MCOIMAPMessage.gmailMessageID do not match");
        if([_messagesWithUnfinishedDeletion containsIndex:imapMessage.gmailMessageID]) {
            SM_LOG_INFO(@"message with id %llu is deleted locally", imapMessage.gmailMessageID);
            continue;
        }

        NSString *plainTextBody = nil;
        BOOL hasAttachments = NO;
        
        if(plainTextBodies != nil && plainTextBodies[i] != (NSString*)[NSNull null]) {
            plainTextBody = plainTextBodies[i];
        }
        
        if(hasAttachmentsFlags != nil && [hasAttachmentsFlags[i] boolValue]) {
            hasAttachments = YES;
        }
        
        NSAssert(_messageThreadCollection.messageThreads.count == _messageThreadCollection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", _messageThreadCollection.messageThreads.count, _messageThreadCollection.messageThreadsByDate.count);

        SM_LOG_DEBUG(@"looking for imap message with id %llu, gmailThreadId %llu", imapMessage.gmailMessageID, imapMessage.gmailThreadID);

        const uint64_t threadId = imapMessage.gmailThreadID;
        NSNumber *threadIdKey = [NSNumber numberWithUnsignedLongLong:threadId];
        SMMessageThread *messageThread = [[_messageThreadCollection messageThreads] objectForKey:threadIdKey];

        NSDate *firstMessageDate = nil;
        NSUInteger oldIndex = NSNotFound;
        
        BOOL threadUpdated = NO;
        BOOL newThreadCreated = NO;

        if(messageThread == nil) {
            messageThread = [[SMMessageThread alloc] initWithThreadId:threadId messageStorage:self];
            [[_messageThreadCollection messageThreads] setObject:messageThread forKey:threadIdKey];
            
            threadUpdated = YES;
            newThreadCreated = YES;
        } else {
            oldIndex = [self getMessageThreadIndexByDate:messageThread];
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            
            SMMessage *firstMessage = messageThread.messagesSortedByDate.firstObject;
            firstMessageDate = [firstMessage date];
        }
        
        BOOL ignoreUpdate = NO;
        if([_messagesWithUnfinishedUpdate containsIndex:imapMessage.gmailMessageID]) {
            SM_LOG_INFO(@"message with id %llu is updated locally", imapMessage.gmailMessageID);
            ignoreUpdate = YES;
        }
        
        BOOL messageIsNew = NO;
        const SMThreadUpdateResult threadUpdateResult = [messageThread updateIMAPMessage:imapMessage ignoreUpdate:ignoreUpdate plainTextBody:plainTextBody hasAttachments:hasAttachments remoteFolder:remoteFolderName session:session unseenCount:unseenMessagesCount messageIsNew:&messageIsNew];
        
        if(messageIsNew) {
            [newMessages addObject:imapMessage];
        }
        
        if(updateDatabase) {
            if(threadUpdateResult != SMThreadUpdateResultNone) {
                if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
                    [[_account database] putMessageToDBFolder:imapMessage folder:remoteFolderName];
                }
                else if(threadUpdateResult == SMThreadUpdateResultFlagsChanged) {
                    [[_account database] updateMessageInDBFolder:imapMessage folder:remoteFolderName];
                }
            }
        }
        
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
            [self insertMessageThreadByDate:messageThread oldIndex:oldIndex];
            updateResult = SMMesssageStorageUpdateResultStructureChanged;
        }
        
        NSAssert(_messageThreadCollection.messageThreads.count == _messageThreadCollection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu (oldIndex %lu, threadUpdated %u, threadUpdateResult %lu)", _messageThreadCollection.messageThreads.count, _messageThreadCollection.messageThreadsByDate.count, oldIndex, threadUpdated, threadUpdateResult);
    }
    
    return updateResult;
}

- (SMMessageStorageUpdateResult)endUpdateWithRemoteFolder:(NSString*)remoteFolder removeVanishedMessages:(BOOL)removeVanishedMessages updateDatabase:(BOOL)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount processNewUnseenMessagesBlock:(void (^)(NSArray *newMessages))processNewUnseenMessagesBlock {
    SM_LOG_DEBUG(@"localFolder '%@'", _localFolder.localName);
    
    SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
    
    NSMutableArray *vanishedMessages = [NSMutableArray array];
    NSMutableArray *vanishedThreads = [NSMutableArray array];

    if(unseenMessagesCount != nil) {
        *unseenMessagesCount = 0;
    }
    
    NSMutableArray *newUnseenMessages = [NSMutableArray array];
    for(NSNumber *threadId in _messageThreadCollection.messageThreads) {
        SMMessageThread *messageThread = [_messageThreadCollection.messageThreads objectForKey:threadId];
        NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread];

        SMThreadUpdateResult threadUpdateResult = [messageThread endUpdateWithRemoteFolder:remoteFolder removeVanishedMessages:removeVanishedMessages vanishedMessages:vanishedMessages addNewUnseenMessages:newUnseenMessages];
        
        if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            [self insertMessageThreadByDate:messageThread oldIndex:oldIndex];
            
            updateResult = SMMesssageStorageUpdateResultStructureChanged;
        } else if(threadUpdateResult == SMThreadUpdateResultFlagsChanged && updateResult == SMThreadUpdateResultNone) {
            updateResult = SMMesssageStorageUpdateResultFlagsChanged;
        }
        
        if(messageThread.messagesCount == 0) {
            [vanishedThreads addObject:messageThread];
        }
        else {
            if(unseenMessagesCount != nil) {
                *unseenMessagesCount += messageThread.unseenMessagesCount;
            }
        }
    }

    // Note that we don't explicitly delete this thread from the DB, because the preceding
    // message thread update automatically removes vanished message threads.
    // Also note that the unseen message count is not needed to be updated, because
    // we've already got it right.
    for(SMMessageThread *messageThread in vanishedThreads) {
        [self deleteMessageThread:messageThread updateDatabase:NO unseenMessagesCount:nil];
    }

    if(removeVanishedMessages) {
        if(updateDatabase) {
            for(SMMessage *message in vanishedMessages) {
                if([message.remoteFolder isEqualToString:remoteFolder]) {
                    [[_account database] removeMessageFromDBFolder:message.uid folder:remoteFolder];
                }
            }
        }
    }
    
    NSAssert(_messageThreadCollection.messageThreads.count == _messageThreadCollection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", _messageThreadCollection.messageThreads.count, _messageThreadCollection.messageThreadsByDate.count);
    
    if(processNewUnseenMessagesBlock != nil) {
        processNewUnseenMessagesBlock(newUnseenMessages);
    }
    
    return updateResult;
}

- (void)cancelUpdate {
    for(NSNumber *threadId in _messageThreadCollection.messageThreads) {
        SMMessageThread *thread = [_messageThreadCollection.messageThreads objectForKey:threadId];
        [thread cancelUpdate];
    }
}

- (void)markMessageThreadAsUpdated:(uint64_t)threadId {
    SMMessageThread *messageThread = [[_messageThreadCollection messageThreads] objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
    [messageThread markAsUpdated];
}

- (SMMessage*)setMessageParser:(MCOMessageParser*)parser attachments:(NSArray*)attachments inlineAttachments:inlineAttachments hasAttachments:(BOOL)hasAttachments plainTextBody:(NSString*)plainTextBody messageId:(uint64_t)messageId threadId:(uint64_t)threadId {
    SMMessageThread *thread = [_messageThreadCollection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
    
    return [thread setMessageParser:parser attachments:attachments inlineAttachments:inlineAttachments hasAttachments:hasAttachments plainTextBody:plainTextBody messageId:messageId];
}

- (BOOL)messageHasData:(uint64_t)messageId threadId:(uint64_t)threadId {
    SMMessageThread *thread = [self messageThreadById:threadId];
    if(thread == nil) {
        SM_LOG_DEBUG(@"thread id %lld not found in local folder %@", threadId, _localFolder.localName);
        return NO;
    }

    return [thread messageHasData:messageId];
}

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index {
    if(index >= [_messageThreadCollection.messageThreadsByDate count]) {
        SM_LOG_DEBUG(@"index %lu is beyond message thread size %lu", index, [_messageThreadCollection.messageThreadsByDate count]);
        return nil;
    }

    return [_messageThreadCollection.messageThreadsByDate objectAtIndex:index];
}

- (SMMessageThread*)messageThreadById:(uint64_t)threadId {
    return [_messageThreadCollection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
}

// TODO: update unseenMessagesCount
- (BOOL)addMessageToStorage:(SMMessage*)message updateDatabase:(BOOL)updateDatabase {
    NSUInteger oldIndex = NSNotFound;

    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:message.threadId];
    SMMessageThread *messageThread = [_messageThreadCollection.messageThreads objectForKey:threadIdNum];
    
    if(messageThread == nil) {
        messageThread = [[SMMessageThread alloc] initWithThreadId:message.threadId messageStorage:self];
        [[_messageThreadCollection messageThreads] setObject:messageThread forKey:threadIdNum];
    }
    else {
        oldIndex = [self getMessageThreadIndexByDate:messageThread];
        NSAssert(oldIndex != NSNotFound, @"message thread not found");
    }

    const SMThreadUpdateResult threadUpdateResult = [messageThread addMessage:message];
    
    if(threadUpdateResult == SMThreadUpdateResultNone) {
        SM_LOG_INFO(@"Message id %llu, threadId %llu already exists in folder %@", message.messageId, message.threadId, _localFolder.localName);
        return FALSE;
    }
    
    if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
        [self insertMessageThreadByDate:messageThread oldIndex:oldIndex];
    }

    if(updateDatabase) {
        if([message isKindOfClass:[SMOutgoingMessage class]]) {
            [[_account database] putOutgoingMessageToDBFolder:(SMOutgoingMessage*)message folder:_localFolder.remoteFolderName];
        }
        else {
            [[_account database] putMessageToDBFolder:message.imapMessage folder:_localFolder.remoteFolderName];
        }
    }
    
    return TRUE;
}

// TODO: update database
// TODO: update unseenMessagesCount
- (void)removeMessageFromStorage:(SMMessage*)message updateDatabase:(BOOL)updateDatabase {
    NSAssert(!updateDatabase, @"TODO: implement updateDatabase");

    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:message.threadId];
    SMMessageThread *messageThread = [_messageThreadCollection.messageThreads objectForKey:threadIdNum];
    
    if(messageThread != nil) {
        NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread];
        if(oldIndex == NSNotFound) {
            SM_LOG_ERROR(@"message thead %llu not found in local folder '%@'", message.threadId, _localFolder.localName);
        }

        const SMThreadUpdateResult threadUpdateResult = [messageThread removeMessage:message];
        
        if(messageThread.messagesCount > 0) {
            SM_LOG_DEBUG(@"thread %llu still not empty", message.threadId);

            if(oldIndex != NSNotFound && threadUpdateResult == SMThreadUpdateResultStructureChanged) {
                [self insertMessageThreadByDate:messageThread oldIndex:oldIndex];
            }
        }
        else {
            [self deleteMessageThread:messageThread updateDatabase:updateDatabase unseenMessagesCount:nil];
        }
    }
    else {
        SM_LOG_ERROR(@"thread %llu not found when attempted to remove message id %llu", message.threadId, message.messageId);
    }
}

@end
