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
#import "SMUserAccount.h"
#import "SMDatabase.h"
#import "SMOperationQueueWindowController.h"
#import "SMOperation.h"
#import "SMOperationQueue.h"
#import "SMOperationExecutor.h"

static const NSUInteger OP_QUEUES_SAVE_DELAY_SEC = 5;

@implementation SMOperationExecutor

- (id)initWithUserAccount:(SMUserAccount*)account {
    self = [super initWithUserAccount:account];
    
    if(self) {

    }
    
    return self;
}

- (void)setSmtpQueue:(SMOperationQueue *)smtpQueue imapQueue:(SMOperationQueue *)imapQueue {
    _smtpQueue = (smtpQueue != nil? smtpQueue : [[SMOperationQueue alloc] init]);
    
    if(_smtpQueue.count > 0) {
        [[_smtpQueue getFirstOp] start];
    }

    _imapQueue = (imapQueue != nil? imapQueue : [[SMOperationQueue alloc] init]);
    
    if(_imapQueue.count > 0) {
        [[_imapQueue getFirstOp] start];
    }

    [self notifyController];
}

- (SMUserAccount*)account {
    return _account;
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

    if(queue.count == 1) {
        [op start];
    }

    [self notifyController];
    [self scheduleOpQueuesSave];
}

- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp {
    SM_LOG_DEBUG(@"op %@, replacementOp %@", op, replacementOp);

    NSAssert(op.opKind == replacementOp.opKind, @"op kind %u and replacement op kind %u don't match", op.opKind, replacementOp.opKind);

    SMOperationQueue *queue = [self getQueue:op.opKind];
    
    NSAssert([queue getFirstOp] == op, @"current first op doesn't match the op being replaced");

    [queue replaceFirstOp:replacementOp];

    [replacementOp start];

    [self notifyController];
    [self scheduleOpQueuesSave];
}

- (void)completeOperation:(SMOperation*)op {
    SM_LOG_DEBUG(@"op %@", op);
    
    SMOperationQueue *queue = [self getQueue:op.opKind];

    NSAssert([queue getFirstOp] == op, @"first op is not the completed op");

    [queue popFirstOp];

    if(queue.count > 0) {
        [[queue getFirstOp] start];
    }

    [self notifyController];
    [self scheduleOpQueuesSave];
}

- (void)restartOperation:(SMOperation*)op {
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
        
        if(queue.count > 0) {
            [[queue getFirstOp] start];
        }
    } else {
        [queue removeOp:op];
    }
    
    [self notifyController];
    [self scheduleOpQueuesSave];
}

- (NSUInteger)operationsCount {
    return _smtpQueue.count + _imapQueue.count;
}

- (SMOperation*)getOpAtIndex:(NSUInteger)index {
    NSUInteger offset = index;
    
    if(offset < _smtpQueue.count) {
        return [_smtpQueue getOpAtIndex:offset];
    }
    
    offset -= _smtpQueue.count;

    if(offset < _imapQueue.count) {
        return [_imapQueue getOpAtIndex:offset];
    }
    
    NSAssert(nil, @"bad index %lu (_smtpQueue.size %lu, imap _imapQueue.size %lu)", index, _smtpQueue.count, _imapQueue.count);
    return nil;
}

- (void)notifyController {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationQueueWindowController] reloadOperationQueue];
}

- (void)scheduleOpQueuesSave {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveOpQueues) object:nil];
    [self performSelector:@selector(saveOpQueues) withObject:nil afterDelay:OP_QUEUES_SAVE_DELAY_SEC];
}

- (void)saveSMTPQueue {
    [[_account database] saveOpQueue:_smtpQueue queueName:@"SMTPQueue"];
}

- (void)saveIMAPQueue {
    [[_account database] saveOpQueue:_imapQueue queueName:@"IMAPQueue"];
}

- (void)saveOpQueues {
    [self saveSMTPQueue];
    [self saveIMAPQueue];
}

@end
