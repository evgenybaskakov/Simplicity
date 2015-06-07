//
//  SMOperation.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;
@class MCOOperation;

@interface SMOperation : NSObject

@property MCOOperation *currentOp;

- (void)start;
- (void)restart;
- (void)cancel;
- (void)complete;
- (void)enqueue;
- (void)replaceWith:(SMOperation*)op;
- (NSString*)name;

@end
