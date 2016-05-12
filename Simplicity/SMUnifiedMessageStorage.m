//
//  SMUnifiedMessageStorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessage.h"
#import "SMMessageStorage.h"
#import "SMMessageComparators.h"
#import "SMMessageThread.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMessageStorage.h"

@implementation SMUnifiedMessageStorage {
    NSMutableArray<SMMessageStorage*> *_attachedMessageStorages;
    NSMutableOrderedSet<SMMessageThread*> *_messageThreadsByDate;
}

- (id)initWithUserAccount:(SMUnifiedAccount *)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _attachedMessageStorages = [NSMutableArray array];
        _messageThreadsByDate = [NSMutableOrderedSet orderedSet];
    }
    
    return self;
}

- (void)attachMessageStorage:(SMMessageStorage*)messageStorage {
    NSAssert([_attachedMessageStorages indexOfObject:messageStorage] == NSNotFound, @"messageStorage already attached");
    
    [_attachedMessageStorages addObject:messageStorage];
    
    [messageStorage attachToUnifiedMessageStorage:self];
}

- (void)detachMessageStorage:(SMMessageStorage*)messageStorage {
    [messageStorage deattachFromUnifiedMessageStorage];

    [_attachedMessageStorages removeObject:messageStorage];
}

- (void)addMessageThread:(SMMessageThread*)messageThread {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSComparator messageThreadComparator = [[appDelegate messageComparators] messageThreadsComparatorByDate];
    NSUInteger index = [_messageThreadsByDate indexOfObject:messageThread inSortedRange:NSMakeRange(0, _messageThreadsByDate.count) options:NSBinarySearchingInsertionIndex usingComparator:messageThreadComparator];
    
    NSAssert(index != NSNotFound, @"message thread not found");
    
    if(index < _messageThreadsByDate.count) {
        NSAssert([_messageThreadsByDate objectAtIndex:index] != messageThread, @"message thread being inserted already exists");
    }
    
    [_messageThreadsByDate insertObject:messageThread atIndex:index];
}

- (void)removeMessageThread:(SMMessageThread*)messageThread {
    [_messageThreadsByDate removeObject:messageThread];
}

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index {
    NSOrderedSet *sortedMessageThreads = _messageThreadsByDate;

    if(index >= sortedMessageThreads.count) {
        SM_LOG_WARNING(@"index %lu is beyond message thread size %lu", index, sortedMessageThreads.count);
        return nil;
    }
    
    return [sortedMessageThreads objectAtIndex:index];
}

- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSComparator messageThreadComparator = [[appDelegate messageComparators] messageThreadsComparatorByDate];
    NSOrderedSet *sortedMessageThreads = _messageThreadsByDate;
    NSUInteger idx = [sortedMessageThreads indexOfObject:messageThread inSortedRange:NSMakeRange(0, sortedMessageThreads.count) options:NSBinarySearchingFirstEqual usingComparator:messageThreadComparator];
    
    return idx;
}

- (NSUInteger)messageThreadsCount {
    return _messageThreadsByDate.count;
}

@end
