//
//  SMLabelSelectionTableRowView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/7/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLabelSelectionTableRowView.h"

@interface SMLabelSelectionTableRowView()
@property BOOL mouseInside;
@property NSTrackingArea *trackingArea;
@end

@implementation SMLabelSelectionTableRowView

@dynamic mouseInside;

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)setMouseInside:(BOOL)value {
    if(mouseInside != value) {
        mouseInside = value;
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)mouseInside {
    return mouseInside;
}

- (void)ensureTrackingArea {
    if(_trackingArea == nil) {
        _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:_trackingArea]) {
        [self addTrackingArea:_trackingArea];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    self.mouseInside = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
    self.mouseInside = NO;
}

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    if(self.mouseInside) {
        [[NSColor blackColor] set];
        NSRectFill(self.bounds);
    }
    else {
        [self.backgroundColor set];
        NSRectFill(self.bounds);
    }
}

@end
