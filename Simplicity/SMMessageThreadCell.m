//
//  SMMessageThreadCell.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageThreadCell.h"

@implementation SMMessageThreadCell

- (id)initWithMessage:(SMMessage*)message viewController:(SMMessageThreadCellViewController*)viewController {
    self = [super init];

    if(self) {
        _message = message;
        _viewController = viewController;
    }

    return self;
}

@end

