//
//  SMFlippedView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFlippedView.h"

@implementation SMFlippedView {
    NSColor *_backgroundColor;
}

- (id)initWithFrame:(NSRect)frameRect backgroundColor:(NSColor*)backgroundColor {
    self = [super initWithFrame:frameRect];
    
    if(self) {
        _backgroundColor = backgroundColor;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    if(_backgroundColor) {
        [_backgroundColor setFill];
        NSRectFill(dirtyRect);
    }
    
    [super drawRect:dirtyRect];
}

- (BOOL)isFlipped {
    return YES;
}

@end
