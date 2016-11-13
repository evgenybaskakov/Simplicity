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
@property (weak) IBOutlet NSButton *matchCaseCheckbox;
@property (weak) IBOutlet NSSegmentedControl *directionButtons;
@property (weak) IBOutlet NSButton *doneButton;
@property (weak) IBOutlet NSButton *replaceButton;
@property (weak) IBOutlet NSButton *replaceAllButton;
@end

@implementation SMEditorFindContentsPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _findField.nextKeyView = _matchCaseCheckbox;
    _matchCaseCheckbox.nextKeyView = _directionButtons;
    _directionButtons.nextKeyView = _doneButton;
    _doneButton.nextKeyView = _replaceField;
    _replaceField.nextKeyView = _replaceButton;
    _replaceButton.nextKeyView = _replaceAllButton;
    _replaceAllButton.nextKeyView = _findField;
    
    _directionButtons.selectedSegment = 1; // next, initially
}

- (IBAction)findFieldAction:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    const BOOL forward = YES;

    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:forward restart:NO];
}

- (IBAction)directionButtonsAction:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    const BOOL forward = (_directionButtons.selectedSegment == 1? YES : NO);
    
    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:forward restart:NO];
}

- (IBAction)matchCaseCheckbox:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    
    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:YES restart:YES];
}

- (IBAction)doneButtonAction:(id)sender {
    [_messageEditorViewController removeFindContentsResults];
    [_messageEditorViewController hideFindContentsPanel];
}

- (IBAction)replaceFieldAction:(id)sender {
}

- (IBAction)replaceButtonAction:(id)sender {
    const BOOL matchCase = (_matchCaseCheckbox.state == NSOnState);
    const BOOL forward = (_directionButtons.selectedSegment == 1? YES : NO);

    [_messageEditorViewController replaceOccurrence:_replaceField.stringValue];

    [self doFindContentsSearch:_findField.stringValue matchCase:matchCase forward:forward restart:NO];
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
