//
//  SMMessageThreadInfoViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageThread;
@class SMMessageThreadViewController;

@interface SMMessageThreadInfoViewController : NSViewController

@property __weak SMMessageThreadViewController *messageThreadViewController;

+ (NSUInteger)infoHeaderHeight;

- (void)setMessageThread:(SMMessageThread*)messageThread;
- (void)updateMessageThread;

- (void)addLabel:(NSString*)label;
- (void)removeLabel:(NSString*)label;

@end
