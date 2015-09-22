//
//  SMNewLabelWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/5/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMNewLabelWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic) IBOutlet NSTextField *labelName;
@property (nonatomic) IBOutlet NSPopUpButton *nestingLabelName;
@property (nonatomic) IBOutlet NSButton *labelNestedCheckbox;
@property (nonatomic) IBOutlet NSColorWell *labelColorWell;

@property NSString *suggestedNestingLabel;

- (IBAction)createAction:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)toggleNestedLabelAction:(id)sender;

@end
