//
//  SMMessageThreadDescriptor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/2/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadDescriptorEntry.h"
#import "SMMessageThreadDescriptor.h"

@implementation SMMessageThreadDescriptor

- (id)initWithMessageThread:(SMMessageThread*)messageThread {
    self = [super init];
    
    if(self) {
        _threadId = messageThread.threadId;
        _messagesCount = messageThread.messagesCount;
        
        NSMutableArray *entries = [NSMutableArray arrayWithCapacity:_messagesCount];
        
        NSUInteger i = 0;
        for(SMMessage *message in messageThread.messagesSortedByDate) {
            entries[i++] = [[SMMessageThreadDescriptorEntry alloc] initWithFolderName:message.remoteFolder uid:message.uid];
        }
        
        _entries = entries;
    }
    
    return self;
}

- (id)initWithMessageThreadId:(uint64_t)threadId {
    self = [super init];
    
    if(self) {
        _threadId = threadId;
        _messagesCount = 0;
        _entries = [NSMutableArray array];
    }
    
    return self;
}

- (void)addEntry:(SMMessageThreadDescriptorEntry *)entry {
    [((NSMutableArray*)_entries) addObject:entry];

    _messagesCount++;
}

@end
