//
//  SMAbstractMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessageThread;

@protocol SMAbstractMessageStorage

@property (readonly) NSUInteger messageThreadsCount;

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index;
- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread;

@end
