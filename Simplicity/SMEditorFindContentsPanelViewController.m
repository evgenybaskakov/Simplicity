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

@property (weak) IBOutlet NSVisualEffectView *containerView;

@property (weak) IBOutlet NSButton *matchCaseCheckbox;
@property (weak) IBOutlet NSSegmentedControl *directionButtons;
@property (weak) IBOutlet NSButton *doneButton;
@property (weak) IBOutlet NSButton *replaceButton;
@property (weak) IBOutlet NSButton *replaceAllButton;

@property (weak) IBOutlet NSLayoutConstraint *bottomFindFieldConstraint;

@property (weak) IBOutlet NSLayoutConstraint *leftReplaceFieldConstraint;
@property (weak) IBOutlet NSLayoutConstraint *topReplaceFieldConstraint;
@property (weak) IBOutlet NSLayoutConstraint *bottomReplaceFieldConstraint;
@property (weak) IBOutlet NSLayoutConstraint *rightReplaceFieldConstraint;
@property (weak) IBOutlet NSLayoutConstraint *bottomReplaceButtonConstraint;
@property (weak) IBOutlet NSLayoutConstraint *rightReplaceButtonConstraint;
@property (weak) IBOutlet NSLayoutConstraint *bottomReplaceAllButtonConstraint;
@property (weak) IBOutlet NSLayoutConstraint *rightReplaceAllButtonConstraint;

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
    [_messageEditorViewController replaceOccurrence:_replaceField.stringValue];
}

- (IBAction)replaceButtonAction:(id)sender {
    [_messageEditorViewController replaceOccurrence:_replaceField.stringValue];
}

- (IBAction)replaceAllButtonAction:(id)sender {
    [_messageEditorViewController replaceAllOccurrences:_replaceField.stringValue];
}

- (void)doFindContentsSearch:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward restart:(BOOL)restart {
    if(restart) {
        [_messageEditorViewController removeFindContentsResults];
    }
    
    [_messageEditorViewController findContents:stringToFind matchCase:matchCase forward:forward];
}

- (void)showReplaceControls {
    [_containerView removeConstraint:_bottomFindFieldConstraint];

    [_containerView addSubview:_replaceField];
    [_containerView addSubview:_replaceButton];
    [_containerView addSubview:_replaceAllButton];

    [_containerView addConstraint:_leftReplaceFieldConstraint];
    [_containerView addConstraint:_topReplaceFieldConstraint];
    [_containerView addConstraint:_bottomReplaceFieldConstraint];
    [_containerView addConstraint:_rightReplaceFieldConstraint];
    [_containerView addConstraint:_bottomReplaceButtonConstraint];
    [_containerView addConstraint:_rightReplaceButtonConstraint];
    [_containerView addConstraint:_bottomReplaceAllButtonConstraint];
    [_containerView addConstraint:_rightReplaceAllButtonConstraint];
    
    [self.view setNeedsLayout:YES];
}

- (void)hideReplaceControls {
    [_containerView removeConstraint:_leftReplaceFieldConstraint];
    [_containerView removeConstraint:_topReplaceFieldConstraint];
    [_containerView removeConstraint:_bottomReplaceFieldConstraint];
    [_containerView removeConstraint:_rightReplaceFieldConstraint];
    [_containerView removeConstraint:_bottomReplaceButtonConstraint];
    [_containerView removeConstraint:_rightReplaceButtonConstraint];
    [_containerView removeConstraint:_bottomReplaceAllButtonConstraint];
    [_containerView removeConstraint:_rightReplaceAllButtonConstraint];
    
    [_replaceField removeFromSuperview];
    [_replaceButton removeFromSuperview];
    [_replaceAllButton removeFromSuperview];

    [_containerView addConstraint:_bottomFindFieldConstraint];
    
    _bottomFindFieldConstraint.constant = 5;

    [self.view setNeedsLayout:YES];
}

@end
