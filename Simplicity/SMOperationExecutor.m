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

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    
    if (self) {
        _smtpQueue = [coder decodeObjectForKey:@"_smtpQueue"];
        _imapChangeQueue = [coder decodeObjectForKey:@"_imapChangeQueue"];
        _imapCheckQueue = [coder decodeObjectForKey:@"_imapCheckQueue"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_smtpQueue forKey:@"_smtpQueue"];
    [coder encodeObject:_imapChangeQueue forKey:@"_imapChangeQueue"];
    [coder encodeObject:_imapCheckQueue forKey:@"_imapCheckQueue"];
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
