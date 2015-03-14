//
//  SMMessageThreadInfoViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageThread;

@interface SMMessageThreadInfoViewController : NSViewController

+ (NSUInteger)infoHeaderHeight;

- (void)setMessageThread:(SMMessageThread*)messageThread;
- (void)updateMessageThread;

@end
