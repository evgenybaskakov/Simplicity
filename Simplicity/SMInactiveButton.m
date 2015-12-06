//
//  SMInactiveButton.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMInactiveButton.h"

@implementation SMInactiveButton

- (void)mouseDown:(NSEvent *)theEvent {
    // Ignore click - just pass it to the superview.
    [self.superview mouseDown:theEvent];
}

@end
