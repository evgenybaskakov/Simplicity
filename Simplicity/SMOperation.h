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
@class MCOOperation;

@interface SMOperation : NSObject<NSCoding>

@property (readonly) NSDate *timeCreated;
@property (readonly) SMOpKind opKind;

@property (nonatomic) id postActionTarget;
@property (nonatomic) SEL postActionSelector;

@property MCOOperation *currentOp;

- (id)initWithKind:(SMOpKind)opKind;
- (void)start;
- (void)fail;
- (Boolean)cancelOp;
- (void)complete;
- (void)enqueue;
- (void)replaceWith:(SMOperation*)op;
- (NSString*)name;
- (NSString*)details;
- (void)encodeWithCoder:(NSCoder*)coder;
- (id)initWithCoder:(NSCoder*)coder;

@end
