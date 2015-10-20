//
//  SMThreadSafeQueue.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/19/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMThreadSafeOperationQueue.h"

@implementation SMThreadSafeOperationQueue {
    NSMutableArray *_queue;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _queue = [NSMutableArray array];
    }
    
    return self;
}

- (NSUInteger)count {
    @synchronized(self) {
        return _queue.count;
    }
}

- (void)pushBackOperation:(void (^)())op {
    @synchronized(self) {
        [_queue addObject:op];
    }
}

- (void(^)())popFrontOperation {
    @synchronized(self) {
        if(_queue.count == 0) {
            return nil;
        }
        
        void (^firstOp)() = _queue[0];

        [_queue removeObjectAtIndex:0];
        
        return firstOp;
    }
}

@end
