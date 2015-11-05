//
//  SMNewAccountWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/3/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppController.h"
#import "SMAppDelegate.h"
#import "SMStringUtils.h"
#import "SMNewAccountWindowController.h"

@interface SMNewAccountWindowController ()

#pragma mark Main view

@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *backButton;
@property (weak) IBOutlet NSButton *nextButton;
@property (weak) IBOutlet NSView *stepPanelView;

#pragma mark Step 1

@property (strong) IBOutlet NSView *step1PanelView;

@property (weak) IBOutlet NSTextField *fullNameField;
@property (weak) IBOutlet NSTextField *emailAddressField;
@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSImageView *fullNameInvalidMarker;
@property (weak) IBOutlet NSImageView *emailInvalidMarker;

#pragma mark Step 2

@property (strong) IBOutlet NSView *step2PanelView;

@property (weak) IBOutlet NSButton *gmailSelectionButton;
@property (weak) IBOutlet NSButton *yahooSelectionButton;
@property (weak) IBOutlet NSButton *outlookSelectionButton;
@property (weak) IBOutlet NSButton *yandexSelectionButton;
@property (weak) IBOutlet NSButton *customServerSelectionButton;

@end

@implementation SMNewAccountWindowController {
    BOOL _fullNameValid;
    BOOL _emailAddressValid;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [_stepPanelView addSubview:_step1PanelView];
    _step1PanelView.frame = NSMakeRect(0, 0, _stepPanelView.frame.size.width, _stepPanelView.frame.size.height);
    
    [self showStep:0];
}

- (void)windowWillClose:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

- (IBAction)closeNewAccountAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

- (IBAction)cancelAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

- (IBAction)backAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)nextAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)fullNameEnterAction:(id)sender {
    _fullNameValid = (_fullNameField.stringValue != nil && _fullNameField.stringValue.length > 0)? YES : NO;
    _fullNameInvalidMarker.hidden = (_fullNameValid? YES : NO);
    _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
}

- (IBAction)emailAddressEnterAction:(id)sender {
    _emailAddressValid = [SMStringUtils emailAddressValid:_emailAddressField.stringValue];
    _emailInvalidMarker.hidden = (_emailAddressValid? YES : NO);
    _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
}

- (IBAction)passwordEnterAction:(id)sender {
}

- (void)showStep:(NSUInteger)step {
    if(step == 0) {
        _backButton.hidden = YES;
        _nextButton.stringValue = @"Next";
        _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
    }

    if(step == 1) {
        _backButton.hidden = NO;
        _nextButton.stringValue = @"Finish";
    }
}

@end
