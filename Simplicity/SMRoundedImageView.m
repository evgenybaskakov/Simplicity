//
//  SMRoundedImageView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/16/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMRoundedImageView.h"

@implementation SMRoundedImageView

- (void)setCornerRadius:(NSUInteger)cornerRadius {
    _cornerRadius = cornerRadius;
    
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    if(_cornerRadius == 0) {
        [super drawRect:dirtyRect];
    }
    else {
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(dirtyRect, _insetsWidth, _insetsWidth) xRadius:_cornerRadius yRadius:_cornerRadius];
        
        [path setLineWidth:0];
        [path addClip];
        
        [self.image drawAtPoint:NSZeroPoint fromRect:dirtyRect operation:NSCompositeSourceOver fraction:1.0];
    }
}

@end
