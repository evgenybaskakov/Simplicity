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

    [NSGraphicsContext saveGraphicsState];
    
    NSShadow* shadow = [[NSShadow alloc] init];
    [shadow setShadowOffset:NSMakeSize(0.1, -0.5)];
    [shadow setShadowBlurRadius:1.0];
    [shadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.2]];
    [shadow set];
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:focusRingRect xRadius:cornerRadius yRadius:cornerRadius];
    [[NSColor whiteColor] set];
    [path fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
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
