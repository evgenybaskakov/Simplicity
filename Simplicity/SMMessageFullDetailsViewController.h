//
//  SMMessageFullDetailsViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessage;
@class SMMessageThreadCellViewController;

@interface SMMessageFullDetailsViewController : NSViewController<NSTokenFieldDelegate>

@property (readonly, nonatomic) CGFloat contentViewHeight;

- (void)setEnclosingThreadCell:(SMMessageThreadCellViewController *)enclosingThreadCell;
- (void)setMessage:(SMMessage*)message;

- (void)invalidateIntrinsicContentViewSize;

@end
