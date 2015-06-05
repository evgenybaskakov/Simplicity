//
//  SMOperationExecutor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMOperation.h"
#import "SMOperationQueue.h"
#import "SMOperationExecutor.h"

@implementation SMOperationExecutor {
    SMOperationQueue *_queue;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _queue = [[SMOperationQueue alloc] init];
    }
    
    return self;
}

- (void)enqueueOperation:(SMOperation*)op {
    [_queue putOp:op];

    if(_queue.size == 1) {
        [op start];
    }
}

- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp {
    SMOperation *fop = [_queue getFirstOp];
    NSAssert(fop == op, @"current first op doesn't match the op being replaced");

    [_queue replaceFirstOp:replacementOp];

    [replacementOp start];
}

- (void)completeOperation:(SMOperation*)op {
    NSAssert([_queue getFirstOp] == op, @"first op is not the completed op");

    [_queue popFirstOp];

    if(_queue.size > 0) {
        [[_queue getFirstOp] start];
    }
}

@end
