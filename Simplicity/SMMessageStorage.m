 //
//  SM_messagestorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMDatabase.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMessageComparators.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadCollection.h"
#import "SMMessageThreadDescriptor.h"
#import "SMAppDelegate.h"

@implementation SMMessageStorage {
@private
    // keeps a collection of message threads for each folder
    NSMutableDictionary *_foldersMessageThreadsMap;
    NSMutableDictionary *_messagesThreadsMap;
}

@synthesize comparators;

- (id)init {
    self = [ super init ];

    if(self) {
        comparators = [SMMessageComparators new];
        
        _foldersMessageThreadsMap = [NSMutableDictionary new];
        _messagesThreadsMap = [NSMutableDictionary new];
    }

    return self;
}

- (void)ensureLocalFolderExists:(NSString*)localFolder {
    SM_LOG_DEBUG(@"folder name '%@", localFolder);
    
    SMMessageThreadCollection *collection = [_foldersMessageThreadsMap objectForKey:localFolder];
    
    if(collection == nil)
        [_foldersMessageThreadsMap setValue:[SMMessageThreadCollection new] forKey:localFolder];
}

- (void)removeLocalFolder:(NSString*)localFolder {
    // TODO: scan message threads in this folder; if any of them doesn't belong to other folders, delete their messages from _messagesThreadsMap
    //       this will prevent the memory leak
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
    
    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:messageThread.threadId];
    for(SMMessage *m in messageThread.messagesSortedByDate) {
        [_messagesThreadsMap setObject:threadIdNum forKey:[NSNumber numberWithUnsignedInt:m.uid]];
    }
}

- (NSNumber*)messageThreadByMessageUID:(uint32_t)uid {
    return [_messagesThreadsMap objectForKey:[NSNumber numberWithUnsignedInt:uid]];
}

- (void)deleteMessageThreads:(NSArray*)messageThreads fromLocalFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection, @"bad folder collection");

    [self deleteMessageThreads:messageThreads fromCollection:collection localFolder:localFolder updateDatabase:updateDatabase unseenMessagesCount:unseenMessagesCount];
}

- (void)deleteMessageThreads:(NSArray *)messageThreads fromCollection:(SMMessageThreadCollection*)collection localFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    for(SMMessageThread *thread in messageThreads) {
        for(SMMessage *m in thread.messagesSortedByDate) {
            if(m.unseen && unseenMessagesCount != nil && *unseenMessagesCount > 0) {
                (*unseenMessagesCount)--;
            }

            [_messagesThreadsMap removeObjectForKey:[NSNumber numberWithUnsignedInt:m.uid]];
        }

        [collection.messageThreads removeObjectForKey:[NSNumber numberWithUnsignedLongLong:thread.threadId]];
        [collection.messageThreadsByDate removeObject:thread];
    }
    
    if(updateDatabase) {
        for(SMMessageThread *thread in messageThreads) {
            SM_LOG_INFO(@"Deleting message thread %llu from the database", thread.threadId);
            
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate model] database] removeMessageThreadFromDB:thread.threadId folder:localFolder];
        }
    }
}

- (Boolean)deleteMessageFromStorage:(uint32_t)uid threadId:(uint64_t)threadId localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolder unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    [_messagesThreadsMap removeObjectForKey:[NSNumber numberWithUnsignedInt:uid]];
    
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection, @"bad folder collection");
    
    SMMessageThread *messageThread = [self messageThreadById:threadId localFolder:localFolder];
    NSAssert(messageThread != nil, @"message thread not found for message uid %u, threadId %llu", uid, threadId);
    NSAssert([messageThread getMessageByUID:uid] != nil, @"message uid %u not found in thread with threadId %llu", uid, threadId);

    if(messageThread.messagesCount == 1) {
        [self deleteMessageThreads:[NSArray arrayWithObject:messageThread] fromLocalFolder:localFolder updateDatabase:YES unseenMessagesCount:unseenMessagesCount];
        return true;
    }
    else {
        SMMessage *message = [messageThread getMessageByUID:uid];
        if(message != nil) {
            if(message.unseen && unseenMessagesCount != nil && *unseenMessagesCount > 0) {
                (*unseenMessagesCount)--;
            }
        }
        
        SMMessage *firstMessage = [messageThread.messagesSortedByDate objectAtIndex:0];
        if(firstMessage == message) {
            NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];
            
            [messageThread removeMessageFromMessageThread:uid];
            
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            [self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
            
            return true;
        }
        else {
            [messageThread removeMessageFromMessageThread:uid];
            return false;
        }
    }
}

- (void)deleteMessagesFromStorageByUIDs:(NSArray*)messageUIDs {
    [_messagesThreadsMap removeObjectsForKeys:messageUIDs];
}

- (void)startUpdate:(NSString*)localFolder {
    SM_LOG_DEBUG(@"localFolder '%@'", localFolder);
    
    [self cancelUpdate:localFolder];
}

- (SMMessageStorageUpdateResult)updateIMAPMessages:(NSArray*)imapMessages localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolderName session:(MCOIMAPSession*)session updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount {
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection, @"bad folder collection");
    
    SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
    
    for(MCOIMAPMessage *imapMessage in imapMessages) {
        NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", collection.messageThreads.count, collection.messageThreadsByDate.count);

        SM_LOG_DEBUG(@"looking for imap message with uid %u, gmailThreadId %llu", [imapMessage uid], [imapMessage gmailThreadID]);

        const uint64_t threadId = [imapMessage gmailThreadID];
        NSNumber *threadIdKey = [NSNumber numberWithUnsignedLongLong:threadId];
        SMMessageThread *messageThread = [[collection messageThreads] objectForKey:threadIdKey];

        NSDate *firstMessageDate = nil;
        NSUInteger oldIndex = NSUIntegerMax;
        
        Boolean threadUpdated = NO;
        Boolean newThreadCreated = NO;

        if(messageThread == nil) {
            messageThread = [[SMMessageThread alloc] initWithThreadId:threadId];
            [[collection messageThreads] setObject:messageThread forKey:threadIdKey];
            
            threadUpdated = YES;
            newThreadCreated = YES;
        } else {
            oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            
            SMMessage *firstMessage = messageThread.messagesSortedByDate.firstObject;
            firstMessageDate = [firstMessage date];
        }

        const SMThreadUpdateResult threadUpdateResult = [messageThread updateIMAPMessage:imapMessage remoteFolder:remoteFolderName session:session unseenCount:unseenMessagesCount];
        
        if(updateDatabase) {
            if(threadUpdateResult != SMThreadUpdateResultNone) {
                if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
                    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                    [[[appDelegate model] database] putMessageToDBFolder:imapMessage folder:remoteFolderName];
                }
                else if(threadUpdateResult == SMThreadUpdateResultFlagsChanged) {
                    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                    [[[appDelegate model] database] updateMessageInDBFolder:imapMessage folder:remoteFolderName];
                }
                
                if(threadUpdateResult == SMThreadUpdateResultStructureChanged && !newThreadCreated) {
                    // NOTE: Do not put the new (allocated) message thread to the DB - there's just one message in it.
                    // It will be put in the database on endUpdate if any subsequent updates follow.
                    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                    SMMessageThreadDescriptor *messageThreadDesc = [[SMMessageThreadDescriptor alloc] initWithMessageThread:messageThread];
                    
                    [[[appDelegate model] database] updateMessageThreadInDB:messageThreadDesc folder:localFolder];
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
            [self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
            updateResult = SMMesssageStorageUpdateResultStructureChanged;
        }
        
        NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu (oldIndex %lu, threadUpdated %u, threadUpdateResult %lu)", collection.messageThreads.count, collection.messageThreadsByDate.count, oldIndex, threadUpdated, threadUpdateResult);
    }
    
    return updateResult;
}

- (SMMessageStorageUpdateResult)endUpdate:(NSString*)localFolder removeFolder:(NSString*)remoteFolder removeVanishedMessages:(Boolean)removeVanishedMessages updateDatabase:(Boolean)updateDatabase unseenMessagesCount:(NSUInteger*)unseenMessagesCount processNewUnseenMessagesBlock:(void (^)(NSArray *newMessages))processNewUnseenMessagesBlock {
    SM_LOG_DEBUG(@"localFolder '%@'", localFolder);
    
    SMMessageStorageUpdateResult updateResult = SMMesssageStorageUpdateResultNone;
    
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection, @"bad thread collection");
    
    NSMutableArray *vanishedMessages = [NSMutableArray array];
    NSMutableArray *vanishedThreads = [NSMutableArray array];

    *unseenMessagesCount = 0;
    
    NSMutableArray *newUnseenMessages = [NSMutableArray array];
    for(NSNumber *threadId in collection.messageThreads) {
        SMMessageThread *messageThread = [collection.messageThreads objectForKey:threadId];
        NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];

        SMThreadUpdateResult threadUpdateResult = [messageThread endUpdate:removeVanishedMessages vanishedMessages:vanishedMessages addNewUnseenMessages:newUnseenMessages];
        
        if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
            NSAssert(oldIndex != NSNotFound, @"message thread not found");
            [self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
            
            updateResult = SMMesssageStorageUpdateResultStructureChanged;
        } else if(threadUpdateResult == SMThreadUpdateResultFlagsChanged && updateResult == SMThreadUpdateResultNone) {
            updateResult = SMMesssageStorageUpdateResultFlagsChanged;
        }
        
        if(messageThread.messagesCount == 0) {
            [vanishedThreads addObject:messageThread];
        }
        else {
            *unseenMessagesCount += messageThread.unseenMessagesCount;
        }

        if(updateResult == SMThreadUpdateResultStructureChanged) {
            if(updateDatabase) {
                SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                SMMessageThreadDescriptor *messageThreadDesc = [[SMMessageThreadDescriptor alloc] initWithMessageThread:messageThread];
                
                [[[appDelegate model] database] updateMessageThreadInDB:messageThreadDesc folder:localFolder];
            }
        }
    }

    // Note that we don't explicitly delete this thread from the DB, because the preceding
    // message thread update automatically removes vanished message threads.
    // Also note that the unseen message count is not needed to be updated, because
    // we've already got it right.
    [self deleteMessageThreads:vanishedThreads fromCollection:collection localFolder:localFolder updateDatabase:NO unseenMessagesCount:nil];

    if(removeVanishedMessages) {
        if(updateDatabase) {
            for(SMMessage *message in vanishedMessages) {
                if([message.remoteFolder isEqualToString:remoteFolder]) {
                    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                    [[[appDelegate model] database] removeMessageFromDBFolder:message.uid folder:remoteFolder];
                }
            }
        }
    }
    
    NSAssert(collection.messageThreads.count == collection.messageThreadsByDate.count, @"message threads count %lu not equal to sorted threads count %lu", collection.messageThreads.count, collection.messageThreadsByDate.count);
    
    if(processNewUnseenMessagesBlock != nil) {
        processNewUnseenMessagesBlock(newUnseenMessages);
    }
    
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

- (void)setMessageData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments messageBodyPreview:(NSString*)messageBodyPreview uid:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection, @"bad folder collection");
    
    SMMessageThread *thread = [collection.messageThreads objectForKey:[NSNumber numberWithUnsignedLongLong:threadId]];
    [thread setMessageData:data parser:parser attachments:attachments bodyPreview:messageBodyPreview uid:uid];
}

- (BOOL)messageHasData:(uint32_t)uid localFolder:(NSString*)localFolder threadId:(uint64_t)threadId {
    SMMessageThread *thread = [self messageThreadById:threadId localFolder:localFolder];
//  NSAssert(thread != nil, @"thread id %lld not found in local folder %@", threadId, localFolder);
    if(thread == nil) {
        SM_LOG_DEBUG(@"thread id %lld not found in local folder %@", threadId, localFolder);
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
        SM_LOG_DEBUG(@"index %lu is beyond message thread size %lu", index, [collection.messageThreadsByDate count]);
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

// TODO: update unseenMessagesCount
- (BOOL)addMessage:(SMMessage*)message toLocalFolder:(NSString*)folderName updateDatabase:(Boolean)updateDatabase {
    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:folderName];
    NSAssert(collection != nil, @"No message thread collection for folder %@", folderName);
    
    NSUInteger oldIndex = NSUIntegerMax;

    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:message.threadId];
    SMMessageThread *messageThread = [collection.messageThreads objectForKey:threadIdNum];
    
    if(messageThread == nil) {
        messageThread = [[SMMessageThread alloc] initWithThreadId:message.threadId];
        [[collection messageThreads] setObject:messageThread forKey:threadIdNum];
    }
    else {
        oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:folderName];
        NSAssert(oldIndex != NSNotFound, @"message thread not found");
    }

    const SMThreadUpdateResult threadUpdateResult = [messageThread addMessage:message];
    
    if(threadUpdateResult == SMThreadUpdateResultNone) {
        SM_LOG_INFO(@"Message uid %u, threadId %llu already exists in folder %@", message.uid, message.threadId, folderName);
        return FALSE;
    }
    
    if(threadUpdateResult == SMThreadUpdateResultStructureChanged) {
        [self insertMessageThreadByDate:messageThread localFolder:folderName oldIndex:oldIndex];
    }

    if(updateDatabase) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

        if([message isKindOfClass:[SMOutgoingMessage class]]) {
            [[[appDelegate model] database] putOutgoingMessageToDBFolder:(SMOutgoingMessage*)message folder:folderName];
        }
        else {
            [[[appDelegate model] database] putMessageToDBFolder:message.imapMessage folder:folderName];
        }
    }
    
    return TRUE;
}

// TODO: update database
// TODO: update unseenMessagesCount
- (void)removeMessage:(SMMessage*)message fromLocalFolder:(NSString*)localFolder updateDatabase:(Boolean)updateDatabase {
    NSAssert(!updateDatabase, @"TODO: implement updateDatabase");

    SMMessageThreadCollection *collection = [self messageThreadCollectionForFolder:localFolder];
    NSAssert(collection != nil, @"No message thread collection for folder %@", localFolder);
    
    NSNumber *threadIdNum = [NSNumber numberWithUnsignedLongLong:message.threadId];
    SMMessageThread *messageThread = [collection.messageThreads objectForKey:threadIdNum];
    
    if(messageThread != nil) {
        NSUInteger oldIndex = [self getMessageThreadIndexByDate:messageThread localFolder:localFolder];
        if(oldIndex == NSNotFound) {
            SM_LOG_ERROR(@"message thead %llu not found in local folder '%@'", message.threadId, localFolder);
        }

        const SMThreadUpdateResult threadUpdateResult = [messageThread removeMessage:message];
        
        if(messageThread.messagesCount > 0) {
            SM_LOG_DEBUG(@"thread %llu still not empty", message.threadId);

            if(oldIndex != NSNotFound && threadUpdateResult == SMThreadUpdateResultStructureChanged) {
                [self insertMessageThreadByDate:messageThread localFolder:localFolder oldIndex:oldIndex];
            }
        }
        else {
            [self deleteMessageThreads:@[messageThread] fromCollection:collection localFolder:localFolder updateDatabase:updateDatabase unseenMessagesCount:nil];
        }
    }
    else {
        SM_LOG_ERROR(@"thread %llu not found when attempted to remove message uid %u", message.threadId, message.uid);
    }
}

@end
