//
//  SMMessageListRowView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/3/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageListRowView.h"

@implementation SMMessageListRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)drawSelectionInRect:(NSRect)dirtyRect {
    if (self.selectionHighlightStyle != NSTableViewSelectionHighlightStyleNone) {
        NSColor *color1 = [NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1];
        NSColor *color2 = [NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:color1 endingColor:color2];

        NSRect selectionRect = NSInsetRect(self.bounds, 0, 0);
        NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:0 yRadius:0];
        
        [gradient drawInBezierPath:selectionPath angle:-90.00];
    }
}

@end
