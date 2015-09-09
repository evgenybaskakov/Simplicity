//
//  SMBox2.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/8/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMBox2.h"

@implementation SMBox2

- (void)scrollWheel:(NSEvent *)theEvent {
    [self.superview scrollWheel:theEvent];
}

@end
