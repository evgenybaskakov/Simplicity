//
//  SMOperationQueueViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/6/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMOperationQueueViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTableView *tableView;

- (void)reloadData;

@end
