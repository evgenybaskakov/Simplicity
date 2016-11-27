//
//  SMOperation.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOperation.h"

@implementation SMOperation {
    BOOL _cancelled;
}

- (id)initWithKind:(SMOpKind)opKind operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super init];
    
    if(self) {
        _opKind = opKind;
        _timeCreated = [NSDate dateWithTimeIntervalSinceNow:0];
        _operationExecutor = operationExecutor;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        _postAction = nil;
        _currentOp = nil;
        _timeCreated = [coder decodeObjectForKey:@"_timeCreated"];
        _opKind = (SMOpKind)[coder decodeIntegerForKey:@"_opKind"];
    }
    
    return self;
}

- (SMUserAccount*)account {
    return (SMUserAccount*)_operationExecutor.account;
}

- (void)setOperationExecutor:(SMOperationExecutor*)operationExecutor {
    _operationExecutor = operationExecutor;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_timeCreated forKey:@"_timeCreated"];
    [coder encodeInteger:_opKind forKey:@"_opKind"];
}

- (void)start {
    NSAssert(false, @"start not implemented");
}

- (BOOL)cancelOp {
    return [self cancelOpForced:NO];
}

- (BOOL)cancelOpForced:(BOOL)force {
    _cancelled = YES;
    
    if(!force) {
        if(_currentOp) {
            // we can't cancel operation in progress
            // there's no way to rollback changes already made,
            // and there's no way to ensure that nothing has started yet
            return false;
        }
    }
    
    [_operationExecutor cancelOperation:self];
    
    return true;
}

- (void)fail {
    if(_cancelled) {
        SM_LOG_INFO(@"Op (kind %u) is cancelled, won't be restarted", _opKind);
        return;
    }
    
    [_operationExecutor restartOperation:self];
}

- (void)complete {
    if(_postAction) {
        _postAction(self);
    }
    
    [_operationExecutor completeOperation:self];
}

- (void)enqueue {
    [_operationExecutor enqueueOperation:self];
}

- (void)replaceWith:(SMOperation*)op {
    op.postAction = _postAction; // Inherit the post action from the parent op.
    
    [_operationExecutor replaceOperation:self with:op];
}

- (NSString*)name {
    NSAssert(false, @"not implemented");
    return nil;
}

- (NSString*)details {
    NSAssert(false, @"not implemented");
    return nil;
}

@end
