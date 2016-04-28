//
//  SMOperationQueue.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMOpSendMessage.h"
#import "SMOperationQueue.h"

@implementation SMOperationQueue {
    NSMutableArray<SMOperation*> *_queue;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _queue = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        _queue = [coder decodeObjectForKey:@"_queue"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_queue forKey:@"_queue"];
}

- (void)putOp:(SMOperation*)op {
    [_queue addObject:op];
}

- (void)popFirstOp {
    SM_LOG_DEBUG(@"pop first op %@", _queue[0]);

    NSAssert(_queue.count != 0, @"queue is empty");
    [_queue removeObjectAtIndex:0];
}

- (void)replaceFirstOp:(SMOperation*)op {
    SM_LOG_DEBUG(@"replace first op %@ -> %@", _queue[0], op);
    
    NSAssert(_queue.count != 0, @"queue is empty");
    _queue[0] = op;
}

- (void)removeOp:(SMOperation*)op {
    SM_LOG_DEBUG(@"remove op %@", op);
    
    NSAssert(_queue.count != 0, @"queue is empty");
    [_queue removeObject:op];
}

- (void)clearQueue {
    [_queue removeAllObjects];
}

- (SMOperation*)getFirstOp {
    NSAssert(_queue.count != 0, @"queue is empty");
    return _queue[0];
}

- (SMOperation*)getOpAtIndex:(NSUInteger)index {
    NSAssert(index < _queue.count, @"bad index");
    return _queue[index];
}

- (NSUInteger)count {
    return _queue.count;
}

- (void)cancelSendOpWithMessage:(SMOutgoingMessage*)message {
    for(NSUInteger i = 0; i < _queue.count; i++) {
        SMOperation *op = _queue[i];
        
        if([op isKindOfClass:[SMOpSendMessage class]]) {
            SMOpSendMessage *sendOp = (SMOpSendMessage*)op;
            
            if(sendOp.outgoingMessage == message) {
                [sendOp cancelOpForced:YES];
                break;
            }
        }
    }
}

- (void)setOperationExecutorForPendingOps:(SMOperationExecutor*)operationExecutor {
    for(NSUInteger i = 0; i < _queue.count; i++) {
        [_queue[i] setOperationExecutor:operationExecutor];
    }
}

@end
