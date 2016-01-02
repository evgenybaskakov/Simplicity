//
//  SMOperationExecutor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;
@class SMOperationQueue;

@interface SMOperationExecutor : NSObject

@property (readonly) SMOperationQueue *smtpQueue;
@property (readonly) SMOperationQueue *imapQueue;

- (id)initWithSMTPQueue:(SMOperationQueue*)smtpQueue imapQueue:(SMOperationQueue*)imapQueue;
- (void)enqueueOperation:(SMOperation*)op;
- (void)replaceOperation:(SMOperation*)op with:(SMOperation*)replacementOp;
- (void)completeOperation:(SMOperation*)op;
- (void)restartOperation:(SMOperation*)op;
- (void)cancelOperation:(SMOperation*)op;
- (NSUInteger)operationsCount;
- (SMOperation*)getOpAtIndex:(NSUInteger)index;
- (void)saveSMTPQueue;
- (void)saveIMAPQueue;

@end
