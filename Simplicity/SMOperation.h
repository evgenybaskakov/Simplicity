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
    kIMAPChangeOpKind,
    kIMAPCheckOpKind
} SMOpKind;

@class SMOperation;
@class MCOOperation;

@interface SMOperation : NSObject

@property (readonly) NSDate *timeCreated;
@property (readonly) SMOpKind kind;

@property MCOOperation *currentOp;

- (id)initWithKind:(SMOpKind)kind;
- (void)start;
- (void)restart;
- (void)cancel;
- (void)complete;
- (void)enqueue;
- (void)replaceWith:(SMOperation*)op;
- (NSString*)name;
- (NSString*)details;

@end
