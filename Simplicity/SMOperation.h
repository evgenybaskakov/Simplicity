//
//  SMOperation.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;

@interface SMOperation : NSObject

- (void)start;
- (void)cancel;
- (void)complete;
- (void)enqueue;
- (void)replaceWith:(SMOperation*)op;

@end
