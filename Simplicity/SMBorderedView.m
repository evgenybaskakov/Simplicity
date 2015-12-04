//
//  SMBorderedView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/19/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMBorderedView.h"

@implementation SMBorderedView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
    [self drawBorder:rect];

    [super drawRect:rect];
}

-(void)drawBorder:(NSRect)rect {
    if(rect.size.width < [self bounds].size.width || rect.size.height < [self bounds].size.height)
        return;
    
    NSRect newRect = NSMakeRect(rect.origin.x+2, rect.origin.y+2, rect.size.width-3, rect.size.height-3);
    
    NSBezierPath *textViewSurround = [NSBezierPath bezierPathWithRoundedRect:newRect xRadius:10 yRadius:10];
    [textViewSurround setLineWidth:5.0];
    [textViewSurround stroke];
}

@end
