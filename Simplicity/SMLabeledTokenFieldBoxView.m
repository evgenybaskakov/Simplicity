//
//  SMLabeledTokenFieldBoxView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAddressFieldViewController.h"
#import "SMLabeledTokenFieldBoxView.h"

@implementation SMLabeledTokenFieldBoxView {
    SMAddressFieldViewController *__weak _controller;
}

- (void)setViewController:(SMAddressFieldViewController*)controller {
    _controller = controller;
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(-1, _controller.contentViewHeight);
}

- (void)invalidateIntrinsicContentSize {
    [super invalidateIntrinsicContentSize];
    [_controller invalidateIntrinsicContentViewSize];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
    
    NSRect b = self.bounds;

    if(_drawTopLine) {
        [_lineColor set];
        NSRectFill(NSMakeRect(NSMinX(b) + _topLineOffset, NSMinY(b) + NSHeight(b) - 1, NSWidth(b), 1));
    }
 
    if(_drawBottomLine) {
        [_lineColor set];
        NSRectFill(NSMakeRect(NSMinX(b) + _bottomLineOffset, NSMinY(b), NSWidth(b), 1));
    }
}

@end
