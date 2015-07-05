//
//  SMColorWell.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMColorWellWithIcon.h"

@implementation SMColorWellWithIcon

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;

    NSRect iconArea = NSMakeRect(bounds.origin.x + bounds.size.width/8, bounds.size.height/8 + bounds.size.height/16, bounds.size.width - 2*bounds.size.width/8, bounds.size.height - 2*bounds.size.height/8);
    
    [_icon drawInRect:iconArea];

    NSRect colorArea = NSMakeRect(bounds.origin.x + bounds.size.width/8, bounds.size.height/16, bounds.size.width - 2*bounds.size.width/8, bounds.size.height/16);

    [self.color setStroke];

    NSRectFill(colorArea);
    [NSBezierPath strokeRect:colorArea];
}

@end
