//
//  SMMessageListTableView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/11/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMessageListViewController.h"
#import "SMMessageListTableView.h"

@implementation SMMessageListTableView

-(NSMenu*)menuForEvent:(NSEvent*)theEvent
{
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:mousePoint];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    return [[appController messageListViewController] menuForRow:row];
}

- (void)drawGridInClipRect:(NSRect)clipRect
{
    // See http://stackoverflow.com/questions/5606796/draw-grid-lines-in-nstableview-only-for-populated-rows
    NSRect lastRowRect = [self rectOfRow:[self numberOfRows]-1];
    NSRect myClipRect = NSMakeRect(0, 0, lastRowRect.size.width, NSMaxY(lastRowRect));
    NSRect finalClipRect = NSIntersectionRect(clipRect, myClipRect);
    [super drawGridInClipRect:finalClipRect];
}

@end
