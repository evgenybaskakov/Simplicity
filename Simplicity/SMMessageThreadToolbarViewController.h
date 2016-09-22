//
//  SMMessageThreadToolbarViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMTokenFieldViewController;

@interface SMMessageThreadToolbarViewController : NSViewController

@property (weak) IBOutlet NSSegmentedControl *messageNavigationControl;
@property (weak) IBOutlet NSView *searchFieldView;

@property SMTokenFieldViewController *searchFieldViewController;

@end
