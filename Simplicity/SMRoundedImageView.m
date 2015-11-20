//
//  SMRoundedImageView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/16/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMRoundedImageView.h"

@implementation SMRoundedImageView {
    NSImage *_scaledImage;
}

- (void)setCornerRadius:(NSUInteger)cornerRadius {
    _cornerRadius = cornerRadius;
    
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    if(_nonOriginalBehavior) {
        if(_scaledImage == nil) {
            _scaledImage = self.image;

            if(_scaleImage) {
                _scaledImage.size = self.bounds.size;
            }
        }
        
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, _insetsWidth, _insetsWidth) xRadius:_cornerRadius yRadius:_cornerRadius];
        
        [path setLineWidth:_borderWidth];
        [path addClip];
        
        if(_borderWidth != 0) {
            [_borderColor set];
            [path stroke];
        }

        [_scaledImage drawAtPoint:NSZeroPoint fromRect:self.bounds operation:NSCompositeSourceOver fraction:1.0];
    }
    else {
        [super drawRect:dirtyRect];
    }
}
@end
