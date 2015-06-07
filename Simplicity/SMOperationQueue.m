//
//  SMOperationQueue.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMOperationQueue.h"

@implementation SMOperationQueue {
    NSMutableArray *_queue;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _queue = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)putOp:(SMOperation*)op {
    [_queue addObject:op];
}

- (void)popFirstOp {
    NSAssert(_queue.count != 0, @"queue is empty");
    [_queue removeObjectAtIndex:0];
}

- (void)replaceFirstOp:(SMOperation*)op {
    NSAssert(_queue.count != 0, @"queue is empty");
    _queue[0] = op;
}

- (SMOperation*)getFirstOp {
    NSAssert(_queue.count != 0, @"queue is empty");
    return _queue[0];
}

- (SMOperation*)getOpAtIndex:(NSUInteger)index {
    NSAssert(index < _queue.count, @"bad index");
    return _queue[index];
}

- (NSUInteger)size {
    return _queue.count;
}

@end
