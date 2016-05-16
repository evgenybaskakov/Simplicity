//
//  SMAbstractMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SMAbstractLocalFolder;

@class SMMessageThread;

@protocol SMAbstractMessageStorage

@property (readonly) id<SMAbstractLocalFolder> __weak localFolder;
@property (readonly) NSUInteger messageThreadsCount;

- (SMMessageThread*)messageThreadAtIndexByDate:(NSUInteger)index;
- (NSUInteger)getMessageThreadIndexByDate:(SMMessageThread*)messageThread;

@end
