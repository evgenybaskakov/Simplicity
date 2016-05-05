//
//  SMOperationQueueViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/6/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMOperation.h"
#import "SMOperationExecutor.h"
#import "SMOperationQueueViewController.h"

@implementation SMOperationQueueViewController

// TODO: Issue #78. Should be refreshed when the user changes the current account.

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(appDelegate.currentAccountInactive) {
        SM_LOG_WARNING(@"SMOperationQueueViewController not implemented for unified account");
        return 0;
    }
    
    return [[(SMUserAccount*)appDelegate.currentAccount operationExecutor] operationsCount];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMOperationExecutor *opExecutor = [(SMUserAccount*)appDelegate.currentAccount operationExecutor];
    SMOperation *op = [opExecutor getOpAtIndex:row];
    
    NSAssert(op != nil, @"op is nil");
 
    if([tableColumn.identifier isEqualToString:@"Name"]) {
        return [op name];
    }
    else if([tableColumn.identifier isEqualToString:@"Time"]) {
        return [NSDateFormatter localizedStringFromDate:[op timeCreated] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
    }
    else if([tableColumn.identifier isEqualToString:@"Details"]) {
        return [op details];
    }

    NSAssert(false, @"unexpected column");
    return nil;
}

- (void)reloadOperationQueue {
    [_tableView reloadData];
}

@end
