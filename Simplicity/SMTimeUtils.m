//
//  SMTimeUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMTimeUtils.h"

@implementation SMTimeUtils

+ (void)reportTime:(const char*)what startTime:(NSDate*)startTime {
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:startTime];
    NSLog(@"%s execution time = %f", what, executionTime);
}

@end
