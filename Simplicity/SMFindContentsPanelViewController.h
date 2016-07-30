//
//  SMSearchContentsPanelViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageThreadViewController;

@interface SMFindContentsPanelViewController : NSViewController

@property SMMessageThreadViewController *__weak messageThreadViewController;

@property IBOutlet NSSearchField *searchField;
@property IBOutlet NSButton *matchCaseCheckbox;
@property IBOutlet NSSegmentedControl *forwardBackwardsButton;
@property IBOutlet NSButton *doneButton;

- (IBAction)findContentsSearchAction:(id)sender;
- (IBAction)setMatchCaseAction:(id)sender;
- (IBAction)findNextPrevAction:(id)sender;
- (IBAction)doneAction:(id)sender;

@end
