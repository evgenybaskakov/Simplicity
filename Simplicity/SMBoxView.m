//
//  SMBoxView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMBoxView.h"

@implementation SMBoxView

- (void)setFillColor:(NSColor*)fillColor {
    _fillColor = fillColor;
    [self setNeedsDisplay:YES];
}

- (void)setBoxColor:(NSColor*)boxColor {
    _boxColor = boxColor;
    [self setNeedsDisplay:YES];
}

- (void)setDrawTop:(Boolean)drawTop {
    _drawTop = drawTop;
    [self setNeedsDisplay:YES];
}

- (void)setDrawBotton:(Boolean)drawBottom {
    _drawBottom = drawBottom;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if(_fillColor != nil) {
        [_fillColor setFill];
        NSRectFill(dirtyRect);
    }

    if(_boxColor != nil) {
        if(_drawTop) {
            [_boxColor set];
            NSRectFill(NSMakeRect(0, NSHeight(self.bounds) - 1, NSWidth(self.bounds), 1));
        }

        if(_drawBottom) {
            [_boxColor set];
            NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), 1));
        }
    }
}

@end
