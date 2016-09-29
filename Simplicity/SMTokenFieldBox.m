//
//  SMBox.m
//  CustomTokenField
//
//  Created by Evgeny Baskakov on 2/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMTokenFieldBox.h"

@implementation SMTokenFieldBox

static const NSUInteger cornerRadius = 4;

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    [[NSColor clearColor] set];
    NSRectFill(dirtyRect);
    
    NSRect focusRingRect = _focusedView.frame;

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(focusRingRect, -1, -1) xRadius:cornerRadius yRadius:cornerRadius+2];
    [[NSColor colorWithCalibratedWhite:0.85 alpha:1.0] set];
    [path fill];

    path = [NSBezierPath bezierPathWithRoundedRect:focusRingRect xRadius:cornerRadius yRadius:cornerRadius];
    [[NSColor whiteColor] set];
    [path fill];
    
    if([self containsFirstResponder]) {
        [self setKeyboardFocusRingNeedsDisplayInRect:focusRingRect];
        
        NSSetFocusRingStyle(NSFocusRingBelow);
        
        NSBezierPath *focusRingPath = [NSBezierPath bezierPathWithRoundedRect:focusRingRect xRadius:cornerRadius yRadius:cornerRadius];
        [focusRingPath fill];
    }
}

- (BOOL)containsFirstResponder {
    NSMutableArray *array = [NSMutableArray arrayWithObject:self];
    
    while(array.count > 0) {
        NSView *nearestSubview = array.firstObject;
        
        if([[self window] firstResponder] == nearestSubview) {
            return YES;
        }
        
        [array addObjectsFromArray:nearestSubview.subviews];
        [array removeObjectAtIndex:0];
    }
    
    return NO;
}

@end
