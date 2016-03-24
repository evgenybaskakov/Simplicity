//
//  SMColorView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/23/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMColorView.h"

@implementation SMColorView

- (void)drawRect:(NSRect)dirtyRect {
    if(_backgroundColor) {
        [_backgroundColor setFill];
    
        NSRectFill(self.bounds);
    }
    
    [super drawRect:dirtyRect];
}

@end
