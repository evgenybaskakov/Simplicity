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
        static NSColor *color1 = nil;
        static NSColor *color2 = nil;
        static NSGradient *gradient = nil;

        if(gradient == nil) {
            color1 = [NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1];
            color2 = [NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1];
            gradient = [[NSGradient alloc] initWithStartingColor:color1 endingColor:color2];
        }

        NSRect selectionRect = NSInsetRect(self.bounds, 0, 0);
        NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:0 yRadius:0];
        
        [gradient drawInBezierPath:selectionPath angle:-90.00];
    }
    
    if (self.selected && (self.row > 0)) {
        NSTableView *tableView = (NSTableView*)[self superview];
        [[tableView rowViewAtRow:self.row-1 makeIfNecessary:NO] setNeedsDisplay:YES];
    }
}

- (void)drawSeparatorInRect:(NSRect)dirtyRect {
    if(!self.selected && !self.nextRowSelected) {
        static NSColor *separatorColor = nil;
        if(separatorColor == nil) {
            separatorColor = [NSColor colorWithCalibratedWhite:0.9 alpha:1];
        }

        [separatorColor set];
        
        NSRect separatorRect = self.bounds;
        separatorRect.origin.x = NSMinX(separatorRect) + 22;
        separatorRect.origin.y = NSMaxY(separatorRect) - 1;
        separatorRect.size.height = 1;

        NSRectFill(separatorRect);
    }
}

@end
