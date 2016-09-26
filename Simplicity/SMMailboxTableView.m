//
//  SMMailboxTableView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/8/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMailboxViewController.h"
#import "SMMailboxTableView.h"

@implementation SMMailboxTableView

-(NSMenu*)menuForEvent:(NSEvent*)theEvent
{
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:mousePoint];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    return [[appController mailboxViewController] menuForRow:row];
}

@end
