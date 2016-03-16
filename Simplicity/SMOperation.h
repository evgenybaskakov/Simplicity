//
//  SMOperation.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kSMTPOpKind,
    kIMAPOpKind
} SMOpKind;

@class SMOperation;
@class SMOperationExecutor;
@class MCOOperation;

@interface SMOperation : NSObject<NSCoding> {
    @protected SMOperationExecutor __weak *_operationExecutor;
}

@property (readonly) NSDate *timeCreated;
@property (readonly) SMOpKind opKind;

@property (nonatomic) id postActionTarget;
@property (nonatomic) SEL postActionSelector;

@property MCOOperation *currentOp;

- (id)initWithKind:(SMOpKind)opKind operationExecutor:(SMOperationExecutor*)operationExecutor;
- (void)start;
- (void)fail;
- (Boolean)cancelOp;
- (Boolean)cancelOpForced:(BOOL)force;
- (void)complete;
- (void)enqueue;
- (void)replaceWith:(SMOperation*)op;
- (NSString*)name;
- (NSString*)details;
- (void)encodeWithCoder:(NSCoder*)coder;
- (id)initWithCoder:(NSCoder*)coder;

@end
