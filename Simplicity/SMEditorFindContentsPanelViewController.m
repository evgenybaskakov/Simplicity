//
//  SMEditorFindContentsPanelViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageEditorViewController.h"
#import "SMEditorFindContentsPanelViewController.h"

@interface SMEditorFindContentsPanelViewController ()
@property (weak) IBOutlet NSSearchField *findField;
@property (weak) IBOutlet NSTextField *replaceField;
@property (weak) IBOutlet NSButton *matchCaseCheckbox;
@property (weak) IBOutlet NSSegmentedControl *directionButtons;
@property (weak) IBOutlet NSButton *doneButton;
@property (weak) IBOutlet NSButton *replaceButton;
@property (weak) IBOutlet NSButton *replaceAllButton;
@end

@implementation SMEditorFindContentsPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)findFieldAction:(id)sender {
}

- (IBAction)replaceFieldAction:(id)sender {
}

- (IBAction)matchCaseCheckbox:(id)sender {
}

- (IBAction)directionButtonsAction:(id)sender {
}

- (IBAction)doneButtonAction:(id)sender {
    [_messageEditorViewController hideFindContentsPanel];
}

- (IBAction)replaceButtonAction:(id)sender {
}

- (IBAction)replaceAllButtonAction:(id)sender {
}

@end
