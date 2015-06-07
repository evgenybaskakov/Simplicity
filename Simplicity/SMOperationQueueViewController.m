//
//  SMOperationQueueViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/6/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperation.h"
#import "SMOperationExecutor.h"
#import "SMOperationQueueViewController.h"

@implementation SMOperationQueueViewController

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    return [[[appDelegate appController] operationExecutor] operationsCount];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
 SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMOperationExecutor *opExecutor = [[appDelegate appController] operationExecutor];
    SMOperation *op = [opExecutor getOpAtIndex:row];
    
    NSAssert(op != nil, @"op is nil");
 
    if([tableColumn.identifier isEqualToString:@"Name"]) {
        return [op name];
    }
    else if([tableColumn.identifier isEqualToString:@"Time"]) {
        return @"TODO";
    }
    else if([tableColumn.identifier isEqualToString:@"Details"]) {
        return @"TODO";
    }

    NSAssert(false, @"unexpected column");
    return nil;
}

@end
