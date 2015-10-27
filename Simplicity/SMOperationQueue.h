//
//  SMOperationQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;

@interface SMOperationQueue : NSObject<NSCoding>

@property (readonly) NSUInteger count;

- (void)putOp:(SMOperation*)op;
- (void)popFirstOp;
- (void)replaceFirstOp:(SMOperation*)op;
- (void)removeOp:(SMOperation*)op;
- (SMOperation*)getFirstOp;
- (SMOperation*)getOpAtIndex:(NSUInteger)index;

@end
