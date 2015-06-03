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
    
    // TODO: gen event
    
    [op start]; // TODO: remove
}

- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp {
    SMOperation *fop = [_queue getFirstOp];
    NSAssert(fop == op, @"current first op doesn't match the op being replaced");

    [_queue replaceFirstOp:replacementOp];
    
    // TODO: gen event

    [op start]; // TODO: remove
}

- (void)completeOperation:(SMOperation*)op {
    NSAssert([_queue getFirstOp] == op, @"first op is not the completed op");

    [_queue popFirstOp];

    // TODO: gen event
}

@end
