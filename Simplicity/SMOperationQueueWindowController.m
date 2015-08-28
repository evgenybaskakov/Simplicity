//
//  SMOperationQueueWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/6/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationQueueViewController.h"
#import "SMOperationQueueWindowController.h"

@implementation SMOperationQueueWindowController {
    SMOperationQueueViewController *_operationQueueViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    _operationQueueViewController = [[SMOperationQueueViewController alloc] initWithNibName:@"SMOperationQueueViewController" bundle:nil];
    
    [self setContentViewController:_operationQueueViewController];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self closeOperationQueueWindow];
}

- (void)closeOperationQueueWindow {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] hideOperationQueueSheet];
}

- (void)reloadData {
    [_operationQueueViewController reloadData];
}

- (void)cancelOperation:(id)sender {
    [self closeOperationQueueWindow];
}

@end
