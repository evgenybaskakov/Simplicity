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
    return [_controller intrinsicContentViewSize];
}

- (void)invalidateIntrinsicContentSize {
    [super invalidateIntrinsicContentSize];
    [_controller invalidateIntrinsicContentViewSize];
}

@end
