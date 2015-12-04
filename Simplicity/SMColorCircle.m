//
//  SMColorCircle.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/24/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMColorCircle.h"

@implementation SMColorCircle

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSRect bounds = self.bounds;

    CGFloat circleRadius = (bounds.size.height - 2) / 2.5;
    NSRect circleRect = NSMakeRect(NSMidX(bounds) - circleRadius, NSMidY(bounds) - circleRadius, circleRadius * 2, circleRadius * 2);
    NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[_color highlightWithLevel:0.45] endingColor:_color];
    
    [gradient drawInBezierPath:circlePath angle:-90.00];
}

@end
