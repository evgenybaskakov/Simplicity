//
//  SMOperationExecutor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;

@interface SMOperationExecutor : NSObject

- (void)enqueueOperation:(SMOperation*)op;
- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp;
- (void)completeOperation:(SMOperation*)op;
- (void)failedOperation:(SMOperation*)op;
- (void)cancelOperation:(SMOperation*)op;
- (NSUInteger)operationsCount;
- (SMOperation*)getOpAtIndex:(NSUInteger)index;

@end
