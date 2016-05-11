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
        // nothing yet
    }
    
    return self;
}

- (void)attachMessageStorage:(SMMessageStorage*)messageStorage {
    NSAssert([_attachedMessageStorages indexOfObject:messageStorage] == NSNotFound, @"messageStorage already attached");
    
    [_attachedMessageStorages addObject:messageStorage];
    
    // TODO: Refresh message storage
}

- (void)detachMessageStorage:(SMMessageStorage*)messageStorage {
    // TODO!!! Issue #97.
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
