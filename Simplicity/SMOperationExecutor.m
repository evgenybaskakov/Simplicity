//
//  SMOperationExecutor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationQueueWindowController.h"
#import "SMOperation.h"
#import "SMOperationQueue.h"
#import "SMOperationExecutor.h"

@implementation SMOperationExecutor {
    SMOperationQueue *_smtpQueue;
    SMOperationQueue *_imapQueue;
}

- (id)initWithSMTPQueue:(SMOperationQueue*)smtpQueue imapQueue:(SMOperationQueue*)imapQueue {
    self = [super init];
    
    if(self) {
        _smtpQueue = (smtpQueue != nil? smtpQueue : [[SMOperationQueue alloc] init]);
        _imapQueue = (imapQueue != nil? imapQueue : [[SMOperationQueue alloc] init]);
    }
    
    return self;
}

- (SMOperationQueue*)getQueue:(SMOpKind)kind {
    switch(kind) {
        case kSMTPOpKind: return _smtpQueue;
        case kIMAPOpKind: return _imapQueue;
    }
    
    NSAssert(false, @"bad op kind %u", kind);
    return nil;
}

- (void)enqueueOperation:(SMOperation*)op {
    SM_LOG_DEBUG(@"op %@", op);
    
    SMOperationQueue *queue = [self getQueue:op.opKind];

    [queue putOp:op];

    if(queue.size == 1) {
        [op start];
    }

    [self notifyController];
}

- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp {
    SM_LOG_DEBUG(@"op %@, replacementOp %@", op, replacementOp);

    NSAssert(op.opKind == replacementOp.opKind, @"op kind %u and replacement op kind %u don't match", op.opKind, replacementOp.opKind);

    SMOperationQueue *queue = [self getQueue:op.opKind];
    
    NSAssert([queue getFirstOp] == op, @"current first op doesn't match the op being replaced");

    [queue replaceFirstOp:replacementOp];

    [replacementOp start];

    [self notifyController];
}

- (void)completeOperation:(SMOperation*)op {
    SM_LOG_DEBUG(@"op %@", op);
    
    SMOperationQueue *queue = [self getQueue:op.opKind];

    NSAssert([queue getFirstOp] == op, @"first op is not the completed op");

    [queue popFirstOp];

    if(queue.size > 0) {
        [[queue getFirstOp] start];
    }

    [self notifyController];
}

- (void)failedOperation:(SMOperation*)op {
    SM_LOG_DEBUG(@"op %@", op);
    
    SMOperationQueue *queue = [self getQueue:op.opKind];
    NSAssert([queue getFirstOp] == op, @"first op is not the restarted op");

    // TODO: should monitor the connection status, not just re-trying...

    [op performSelector:@selector(start) withObject:nil afterDelay:5];
}

- (void)cancelOperation:(SMOperation*)op {
    SM_LOG_DEBUG(@"op %@", op);
    
    SMOperationQueue *queue = [self getQueue:op.opKind];
    
    if([queue getFirstOp] == op) {
        [queue popFirstOp];
        
        if(queue.size > 0) {
            [[queue getFirstOp] start];
        }
    } else {
        [queue removeOp:op];
    }
    
    [self notifyController];
}

- (NSUInteger)operationsCount {
    return _smtpQueue.size + _imapQueue.size;
}

- (SMOperation*)getOpAtIndex:(NSUInteger)index {
    NSUInteger offset = index;
    
    if(offset < _smtpQueue.size) {
        return [_smtpQueue getOpAtIndex:offset];
    }
    
    offset -= _smtpQueue.size;

    if(offset < _imapQueue.size) {
        return [_imapQueue getOpAtIndex:offset];
    }
    
    NSAssert(nil, @"bad index %lu (_smtpQueue.size %lu, imap _imapQueue.size %lu)", index, _smtpQueue.size, _imapQueue.size);
    return nil;
}

- (void)notifyController {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationQueueWindowController] reloadData];
}

@end
