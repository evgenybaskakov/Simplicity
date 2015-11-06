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
#import "SMPreferencesController.h"
#import "SMNewAccountWindowController.h"

static const NSUInteger LAST_STEP = 2;

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

#pragma mark Step 3

@property (strong) IBOutlet NSView *step3PanelView;
@property (weak) IBOutlet NSTextField *accountNameField;
@property (weak) IBOutlet NSButton *accountImageButton;
@property (weak) IBOutlet NSImageView *accountNameInvalidMarker;

@end

@implementation SMNewAccountWindowController {
    BOOL _fullNameEntered;
    BOOL _emailAddressEntered;
    BOOL _accountNameEntered;
    BOOL _fullNameValid;
    BOOL _emailAddressValid;
    BOOL _accountNameValid;
    NSUInteger _curStep;
    NSArray *_mailServiceProviderButtons;
    NSArray *_mailServiceProviderTypes;
    NSUInteger _mailServiceProvierIdx;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _mailServiceProvierIdx = NSUIntegerMax;
    
    _mailServiceProviderButtons = @[ _gmailSelectionButton, _yahooSelectionButton, _outlookSelectionButton, _yandexSelectionButton, _customServerSelectionButton ];
    _mailServiceProviderTypes = @[ @(SMServiceProviderType_Gmail), @(SMServiceProviderType_Yahoo), @(SMServiceProviderType_Outlook), @(SMServiceProviderType_Yandex), @(SMServiceProviderType_Custom) ];
    
    _fullNameInvalidMarker.hidden = YES;
    _emailInvalidMarker.hidden = YES;
    _accountNameInvalidMarker.hidden = YES;
    
    [self showStep:0];
}

- (void)windowWillClose:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

//- (IBAction)closeNewAccountAction:(id)sender {
//    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
//    [[appDelegate appController] closeNewAccountWindow];
//}

- (IBAction)cancelAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

- (IBAction)backAction:(id)sender {
    NSAssert(_curStep > 0, @"bad _curStep");
    [self showStep:--_curStep];
}

- (IBAction)nextAction:(id)sender {
    NSAssert(_curStep <= LAST_STEP, @"bad _curStep=%lu", _curStep);
    
    if(_curStep == LAST_STEP) {
        [self finishAccountCreation];
    }
    else {
        [self showStep:++_curStep];
    }
}

- (IBAction)fullNameEnterAction:(id)sender {
    [self validateUserName];
    
    _fullNameEntered = YES;
}

- (IBAction)emailAddressEnterAction:(id)sender {
    [self validateEmailAddress];
    
    _emailAddressEntered = YES;
}

- (IBAction)passwordEnterAction:(id)sender {
    // Nothing to do.
}

- (IBAction)accountNameEnterAction:(id)sender {
    [self validateAccountName];

    _accountNameEntered = YES;
}

- (IBAction)accountImageSelectAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (void)validateUserName {
    _fullNameValid = (_fullNameField.stringValue != nil && _fullNameField.stringValue.length > 0)? YES : NO;
    _fullNameInvalidMarker.hidden = (_fullNameValid? YES : NO);
    _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
}

- (void)validateEmailAddress {
    _emailAddressValid = [SMStringUtils emailAddressValid:_emailAddressField.stringValue];
    _emailInvalidMarker.hidden = (_emailAddressValid? YES : NO);
    _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
}

- (void)validateAccountName {
    _accountNameValid = (_accountNameField.stringValue != nil && _accountNameField.stringValue.length > 0? YES : NO);
    _accountNameInvalidMarker.hidden = (_accountNameValid? YES : NO);
    _nextButton.enabled = (_accountNameValid? YES : NO);
}

- (void)showStep:(NSUInteger)step {
    NSView *subview = nil;
    
    if(step == 0) {
        subview = _step1PanelView;
    }
    else if(step == 1) {
        subview = _step2PanelView;
    }
    else if(step == 2) {
        subview = _step3PanelView;
    }
    
    for(NSView *v in _stepPanelView.subviews) {
        [v removeFromSuperview];
    }
    
    [_stepPanelView addSubview:subview];
    
    subview.frame = NSMakeRect(0, 0, _stepPanelView.frame.size.width, _stepPanelView.frame.size.height);

    if(step == 0) {
        _backButton.hidden = YES;
        _nextButton.hidden = NO;
        _nextButton.title = @"Next";
        _nextButton.enabled = (_fullNameValid && _emailAddressValid? YES : NO);
    }
    else if(step == 1) {
        _backButton.hidden = NO;
        _nextButton.hidden = NO;
        _nextButton.title = @"Next";
        _nextButton.enabled = (_mailServiceProvierIdx != NSUIntegerMax);
    }
    else if(step == LAST_STEP) {
        _backButton.hidden = NO;
        _nextButton.hidden = NO;
        _nextButton.title = @"Finish";
        _nextButton.enabled = (_accountNameValid? YES : NO);
    }
}

- (IBAction)serviceProviderSelectAction:(id)sender {
    NSUInteger i = 0;
    
    for(NSButton *b in _mailServiceProviderButtons) {
        if(sender == b) {
            _mailServiceProvierIdx = i;

            b.state = NSOnState;
        }
        else {
            b.state = NSOffState;
        }
        
        i++;
    }
    
    _nextButton.enabled = YES;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if([obj object] == _fullNameField) {
        if(_fullNameEntered) {
            [self validateUserName];
        }
    }
    else if([obj object] == _emailAddressField) {
        if(_emailAddressEntered) {
            [self validateEmailAddress];
        }
    }
    else if([obj object] == _accountNameField) {
        if(_accountNameEntered) {
            [self validateAccountName];
        }
    }
}

- (void)finishAccountCreation {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
    
    NSAssert(_accountNameField.stringValue != nil && _accountNameField.stringValue.length > 0, @"no account name");
    NSAssert(_fullNameField.stringValue != nil && _fullNameField.stringValue.length > 0, @"no user name");
    NSAssert(_emailAddressField.stringValue != nil && _emailAddressField.stringValue.length > 0, @"no email address");
    NSAssert(_accountImageButton.image != nil, @"no account image");
    
    [[appDelegate preferencesController] addAccountWithName:_accountNameField.stringValue image:_accountImageButton.image userName:_fullNameField.stringValue emailAddress:_emailAddressField.stringValue password:(_passwordField.stringValue != nil? _passwordField.stringValue : nil) type:[_mailServiceProviderTypes[_mailServiceProvierIdx] intValue]];
}

@end
