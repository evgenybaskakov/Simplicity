//
//  SMTableHeaderView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMTableHeaderView.h"

@implementation SMTableHeaderView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (NSRect)headerRectOfColumn:(NSInteger)column {
    NSRect rect = [super headerRectOfColumn:column];
    rect.size.height = 0;
    return rect;
}

@end
