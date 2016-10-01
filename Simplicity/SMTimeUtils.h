//
//  SMTimeUtils.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMTimeUtils : NSObject

+ (void)reportTime:(const char*)what startTime:(NSDate*)startTime;

@end
