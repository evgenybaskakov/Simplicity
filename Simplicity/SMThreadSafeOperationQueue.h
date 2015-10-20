//
//  SMThreadSafeQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/19/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMThreadSafeOperationQueue : NSObject

@property (readonly) NSUInteger count;

- (void)pushBackOperation:(void(^)())op;
- (void(^)())popFrontOperation;

@end
