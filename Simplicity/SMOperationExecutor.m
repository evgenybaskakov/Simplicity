//
//  SMOperationExecutor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationQueueWindowController.h"
#import "SMOperation.h"
#import "SMOperationQueue.h"
#import "SMOperationExecutor.h"

@implementation SMOperationExecutor {
    SMOperationQueue *_smtpQueue;
    SMOperationQueue *_imapChangeQueue;
    SMOperationQueue *_imapCheckQueue;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _smtpQueue = [[SMOperationQueue alloc] init];
        _imapChangeQueue = [[SMOperationQueue alloc] init];
        _imapCheckQueue = [[SMOperationQueue alloc] init];
    }
    
    return self;
}

- (SMOperationQueue*)getQueue:(SMOpKind)kind {
    switch(kind) {
        case kSMTPOpKind: return _smtpQueue;
        case kIMAPChangeOpKind: return _imapChangeQueue;
        case kIMAPCheckOpKind: return _imapCheckQueue;
    }
    
    NSAssert(false, @"bad op kind %u", kind);
    return nil;
}

- (void)enqueueOperation:(SMOperation*)op {
    SMOperationQueue *queue = [self getQueue:op.kind];

    [queue putOp:op];

    if(queue.size == 1) {
        [op start];
    }

    [self notifyController];
}

- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp {
    NSAssert(op.kind == replacementOp.kind, @"op kind %u and replacement op kind %u don't match", op.kind, replacementOp.kind);

    SMOperationQueue *queue = [self getQueue:op.kind];
    
    NSAssert([queue getFirstOp] == op, @"current first op doesn't match the op being replaced");

    [queue replaceFirstOp:replacementOp];

    [replacementOp start];

    [self notifyController];
}

- (void)completeOperation:(SMOperation*)op {
    SMOperationQueue *queue = [self getQueue:op.kind];

    NSAssert([queue getFirstOp] == op, @"first op is not the completed op");

    [queue popFirstOp];

    if(queue.size > 0) {
        [[queue getFirstOp] start];
    }

    [self notifyController];
}

- (NSUInteger)operationsCount {
    return _smtpQueue.size + _imapChangeQueue.size + _imapCheckQueue.size;
}

- (SMOperation*)getOpAtIndex:(NSUInteger)index {
    if(index < _smtpQueue.size)
        return [_smtpQueue getOpAtIndex:index];
    
    index -= _smtpQueue.size;

    if(index < _imapChangeQueue.size)
        return [_imapChangeQueue getOpAtIndex:index];
    
    index -= _imapChangeQueue.size;
    
    NSAssert(index < _imapCheckQueue.size, @"bad index %lu", index);

    return [_imapCheckQueue getOpAtIndex:index];
}

- (void)notifyController {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationQueueWindowController] reloadData];
}

@end
