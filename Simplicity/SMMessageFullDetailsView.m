//
//  SMMessageDetailsView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/26/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageFullDetailsViewController.h"
#import "SMMessageFullDetailsView.h"

@implementation SMMessageFullDetailsView {
    SMMessageFullDetailsViewController *__weak _controller;
}

- (void)setViewController:(SMMessageFullDetailsViewController*)controller {
    _controller = controller;
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(-1, _controller.contentViewHeight);
}

- (void)invalidateIntrinsicContentSize {
    [super invalidateIntrinsicContentSize];
    [_controller invalidateIntrinsicContentViewSize];
}

@end
