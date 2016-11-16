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

@property IBOutlet NSVisualEffectView *containerView;

@property IBOutlet NSButton *matchCaseCheckbox;
@property IBOutlet NSSegmentedControl *directionButtons;
@property IBOutlet NSButton *doneButton;

@property IBOutlet NSButton *replaceButton;
@property IBOutlet NSButton *replaceAllButton;

@property IBOutlet NSLayoutConstraint *leftReplaceFieldConstraint;
@property IBOutlet NSLayoutConstraint *topReplaceFieldConstraint;
@property IBOutlet NSLayoutConstraint *bottomReplaceFieldConstraint;
@property IBOutlet NSLayoutConstraint *rightReplaceFieldConstraint;
@property IBOutlet NSLayoutConstraint *bottomReplaceButtonConstraint;
@property IBOutlet NSLayoutConstraint *rightReplaceButtonConstraint;
@property IBOutlet NSLayoutConstraint *bottomReplaceAllButtonConstraint;
@property IBOutlet NSLayoutConstraint *rightReplaceAllButtonConstraint;

@end

@implementation SMEditorFindContentsPanelViewController {
    CGFloat _delta;
    BOOL _replaceFieldHidden;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _directionButtons.selectedSegment = 1; // next, initially
    _delta = _topReplaceFieldConstraint.constant + _replaceField.bounds.size.height;
    _replaceFieldHidden = NO;

    [self setResponders];
}

- (void)setResponders {
    _findField.nextKeyView = _matchCaseCheckbox;
    _matchCaseCheckbox.nextKeyView = _directionButtons;
    _directionButtons.nextKeyView = _doneButton;
    
    if(_replaceFieldHidden) {
        _doneButton.nextKeyView = _findField;
    }
    else {
        _doneButton.nextKeyView = _replaceField;
        _replaceField.nextKeyView = _replaceButton;
        _replaceButton.nextKeyView = _replaceAllButton;
        _replaceAllButton.nextKeyView = _findField;
    }
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
    if(!_replaceFieldHidden) {
        return;
    }
    _replaceFieldHidden = NO;

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
    
    [self.view setFrame:NSMakeRect(NSMinX(self.view.frame), NSMinY(self.view.frame), NSWidth(self.view.frame), NSHeight(self.view.frame) + _delta)];

    [self setResponders];
}

- (void)hideReplaceControls {
    if(_replaceFieldHidden) {
        return;
    }
    _replaceFieldHidden = YES;
    
    [_replaceField removeFromSuperview];
    [_replaceButton removeFromSuperview];
    [_replaceAllButton removeFromSuperview];
    
    [_containerView removeConstraint:_leftReplaceFieldConstraint];
    [_containerView removeConstraint:_topReplaceFieldConstraint];
    [_containerView removeConstraint:_bottomReplaceFieldConstraint];
    [_containerView removeConstraint:_rightReplaceFieldConstraint];
    [_containerView removeConstraint:_bottomReplaceButtonConstraint];
    [_containerView removeConstraint:_rightReplaceButtonConstraint];
    [_containerView removeConstraint:_bottomReplaceAllButtonConstraint];
    [_containerView removeConstraint:_rightReplaceAllButtonConstraint];
    
    [self.view setFrame:NSMakeRect(NSMinX(self.view.frame), NSMinY(self.view.frame), NSWidth(self.view.frame), NSHeight(self.view.frame) - _delta)];

    [self setResponders];
}

@end
