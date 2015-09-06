//
//  SMMessageDetailsViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/11/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessage;
@class SMMessageThreadCellViewController;

@interface SMMessageDetailsViewController : NSViewController

+ (NSUInteger)messageDetaisHeaderHeight;
+ (CGFloat)headerIconHeightRatio;

+ (NSTextField*)createLabel:(NSString*)text bold:(BOOL)bold;

- (void)setEnclosingThreadCell:(SMMessageThreadCellViewController*)receiver;

- (void)collapse;
- (void)uncollapse;

- (void)setMessage:(SMMessage*)message;
- (void)updateMessage;

- (NSSize)intrinsicContentViewSize;

@end
