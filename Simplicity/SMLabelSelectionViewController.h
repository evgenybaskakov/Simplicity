//
//  SMLabelSelectionViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMFolder;
@class SMMessageThreadInfoViewController;

@interface SMLabelSelectionViewController : NSViewController<NSTableViewDelegate, NSTableViewDataSource>

@property __weak SMMessageThreadInfoViewController *messageThreadInfoViewController;

@property (nonatomic) NSArray<SMFolder*> *folders;

@end
