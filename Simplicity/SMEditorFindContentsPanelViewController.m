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
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:YES restart:NO];
}

- (IBAction)replaceFieldAction:(id)sender {
}

- (IBAction)matchCaseCheckbox:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:YES restart:YES];
}

- (IBAction)directionButtonsAction:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    
    if([_directionButtons selectedSegment] == 0) {
        [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:NO restart:NO];
    }
    else if([_directionButtons selectedSegment] == 1) {
        [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:YES restart:NO];
    }
}

- (IBAction)doneButtonAction:(id)sender {
    [_messageEditorViewController removeFindContentsResults];
    [_messageEditorViewController hideFindContentsPanel];
}

- (IBAction)replaceButtonAction:(id)sender {
}

- (IBAction)replaceAllButtonAction:(id)sender {
}

- (void)doFindContentsSearch:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward restart:(BOOL)restart {
    if(restart) {
        [_messageEditorViewController removeFindContentsResults];
    }
    
    [_messageEditorViewController findContents:stringToFind matchCase:matchCase forward:forward];
}

@end
