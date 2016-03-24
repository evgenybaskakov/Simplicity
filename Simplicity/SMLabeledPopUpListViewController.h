//
//  SMLabeledPopUpListViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/23/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMLabeledPopUpListViewController : NSViewController

@property IBOutlet NSTextField *label;
@property IBOutlet NSPopUpButton *itemList;

@end
