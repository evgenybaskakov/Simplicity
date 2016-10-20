//
//  SMBoxView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMBoxView.h"

@implementation SMBoxView {
    NSTrackingArea *_trackingArea;
    NSColor *_currentFillColor;
}

@synthesize tag;

- (void)setFillColor:(NSColor*)fillColor {
    _fillColor = fillColor;
    _currentFillColor = _fillColor;
    [self setNeedsDisplay:YES];
}

- (void)setBoxColor:(NSColor*)boxColor {
    _boxColor = boxColor;
    [self setNeedsDisplay:YES];
}

- (void)setDrawTop:(BOOL)drawTop {
    _drawTop = drawTop;
    [self setNeedsDisplay:YES];
}

- (void)setDrawBotton:(BOOL)drawBottom {
    _drawBottom = drawBottom;
    [self setNeedsDisplay:YES];
}

- (void)setLeftTopInset:(NSUInteger)inset {
    _leftTopInset = inset;
    [self setNeedsDisplay:YES];
}

- (void)setLeftBottomInset:(NSUInteger)inset {
    _leftBottomInset = inset;
    [self setNeedsDisplay:YES];
}

- (void)setTrackMouse:(BOOL)trackMouse {
    _trackMouse = trackMouse;
    
    [self setNeedsDisplay:YES];
    [self updateTrackingAreas];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if(_currentFillColor != nil) {
        [_currentFillColor setFill];
        NSRectFill(dirtyRect);
    }

    if(_boxColor != nil && _currentFillColor != _mouseInColor) {
        NSRect b = self.bounds;
    
        if(_drawTop) {
            [_boxColor set];
            NSRectFill(NSMakeRect(NSMinX(b) + _leftTopInset, NSMaxY(b) - 1, NSWidth(b), 1));
        }

        if(_drawBottom) {
            [_boxColor set];
            NSRectFill(NSMakeRect(NSMinX(b) + _leftBottomInset, NSMinY(b), NSWidth(b), 1));
        }
    }
}

#pragma mark Tracking

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    if(_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
    }
    
    if(_trackMouse) {
        _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
        
        [self addTrackingArea:_trackingArea];
    }
    else {
        _trackingArea = nil;
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if(_trackMouse) {
        _currentFillColor = _mouseInColor;
        [self setNeedsDisplay:YES];

        if(_mouseEnteredBlock) {
            _mouseEnteredBlock(self);
        }
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    if(_trackMouse) {
        _currentFillColor = _fillColor;
        [self setNeedsDisplay:YES];
        
        if(_mouseExitedBlock) {
            _mouseExitedBlock(self);
        }
    }
}

@end
