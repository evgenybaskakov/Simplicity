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
#import "SMAccountImageSelection.h"
#import "SMPreferencesController.h"
#import "SMPreferencesWindowController.h"
#import "SMMailServiceProvider.h"
#import "SMMailServiceProviderGmail.h"
#import "SMMailServiceProviderICloud.h"
#import "SMMailServiceProviderYahoo.h"
#import "SMMailServiceProviderOutlook.h"
#import "SMMailServiceProviderYandex.h"
#import "SMMailServiceProviderCustom.h"
#import "SMAccountsViewController.h"
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
@property (weak) IBOutlet NSImageView *fullNameInvalidMarker;

#pragma mark Step 2

@property (strong) IBOutlet NSView *step2PanelView;

@property (weak) IBOutlet NSButton *gmailRadioButton;
@property (weak) IBOutlet NSButton *icloudRadioButton;
@property (weak) IBOutlet NSButton *yahooRadioButton;
@property (weak) IBOutlet NSButton *outlookRadioButton;
@property (weak) IBOutlet NSButton *customServerRadioButton;

@property (weak) IBOutlet NSButton *gmailImageButton;
@property (weak) IBOutlet NSButton *icloudImageButton;
@property (weak) IBOutlet NSButton *yahooImageButton;
@property (weak) IBOutlet NSButton *outlookImageButton;
@property (weak) IBOutlet NSButton *customServerImageButton;

#pragma mark Step 3

@property (strong) IBOutlet NSView *step3PanelView;
@property (weak) IBOutlet NSTextField *emailAddressField;
@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSImageView *emailInvalidMarker;

@end

@implementation SMNewAccountWindowController {
    BOOL _fullNameEntered;
    BOOL _emailAddressEntered;
    BOOL _fullNameValid;
    BOOL _emailAddressValid;
    BOOL _accountNameValid;
    NSUInteger _curStep;
    NSArray *_mailServiceProviderButtons;
    NSArray *_mailServiceProviderImageButtons;
    NSArray *_mailServiceProviderDomains;
    NSArray *_mailServiceProviderTypes;
    NSUInteger _mailServiceProvierIdx;
    BOOL _skipProviderSelection;
    BOOL _shouldResetSelectedProvier;
    NSImage *_accountImage;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _mailServiceProviderButtons = @[ _gmailRadioButton, _icloudRadioButton, _yahooRadioButton, _outlookRadioButton, _customServerRadioButton ];
    _mailServiceProviderImageButtons = @[ _gmailImageButton, _icloudImageButton, _yahooImageButton, _outlookImageButton, _customServerImageButton ];
    _mailServiceProviderDomains = @[ @"gmail.com", @"icloud.com", @"yahoo.com", @"outlook.com", @"" ];
    
    [self resetState];
}

- (void)windowWillClose:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeNewAccountWindow];
}

- (void)resetState {
    _fullNameEntered = NO;
    _emailAddressEntered = NO;
    _fullNameValid = NO;
    _emailAddressValid = NO;
    _accountNameValid = NO;
    
    [self resetSelectedProvider];
    [self showStep:0];

    _fullNameField.stringValue = @"";
    _emailAddressField.stringValue = @"";
    _passwordField.stringValue = @"";
    
    _fullNameInvalidMarker.hidden = YES;
    _emailInvalidMarker.hidden = YES;
}

- (IBAction)cancelAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    [appController closeNewAccountWindow];
    
    appController.composeMessageMenuItem.enabled = (appDelegate.accounts.count != 0? YES : NO);
}

- (IBAction)backAction:(id)sender {
    NSAssert(_curStep > 0, @"bad _curStep");
    [self showStep:_curStep - 1];
}

- (IBAction)nextAction:(id)sender {
    NSAssert(_curStep <= LAST_STEP, @"bad _curStep=%lu", _curStep);
    
    if(_curStep == LAST_STEP) {
        [self finishAccountCreation];
    }
    else {
        [self showStep:_curStep + 1];
    }
}

- (IBAction)fullNameEnterAction:(id)sender {
    [self validateUserName:NO];
    
    _fullNameEntered = YES;
    
    if(_fullNameValid) {
        [self.window makeFirstResponder:[(NSView*)sender nextKeyView]];
    }
}

- (IBAction)emailAddressEnterAction:(id)sender {
    [self validateEmailAddress:NO];
    
    _emailAddressEntered = YES;
    
    if(_emailAddressValid) {
        [self.window makeFirstResponder:[(NSView*)sender nextKeyView]];
    }
}

- (IBAction)passwordEnterAction:(id)sender {
    if(_nextButton.enabled) {
        [self nextAction:self];
    }
}

- (void)validateUserName:(BOOL)checkFirst {
    _fullNameValid = (_fullNameField.stringValue != nil && _fullNameField.stringValue.length > 0)? YES : NO;

    if(checkFirst || !_fullNameEntered) {
        _fullNameInvalidMarker.hidden = (_fullNameValid? YES : NO);
    }
    
    _nextButton.enabled = (_fullNameValid? YES : NO);
}

- (void)validateEmailAddress:(BOOL)checkFirst {
    NSString *addr = _emailAddressField.stringValue;
    
    if([addr rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"@"]].location != NSNotFound) {
        _emailAddressValid = [SMStringUtils emailAddressValid:addr];
    }
    else {
        _emailAddressValid = addr.length > 0;
    }

    if(checkFirst || !_emailAddressEntered) {
        _emailInvalidMarker.hidden = (_emailAddressValid? YES : NO);
    }

    _nextButton.enabled = (_emailAddressValid? YES : NO);
}

- (void)resetSelectedProvider {
    if(_mailServiceProvierIdx != NSUIntegerMax) {
        ((NSButton*)_mailServiceProviderButtons[_mailServiceProvierIdx]).state = NSOffState;
        _mailServiceProvierIdx = NSUIntegerMax;
    }
}

- (BOOL)autoSelectServiceProvider {
    NSString *userEmail = [_emailAddressField.stringValue lowercaseString];
    NSAssert(userEmail != nil, @"no user email");

    if([userEmail hasSuffix:@"@gmail.com"]) {
        [self serviceProviderSelectAction:_gmailRadioButton];
    }
    else if([userEmail hasSuffix:@"@icloud.com"]) {
        [self serviceProviderSelectAction:_icloudRadioButton];
    }
    else if([userEmail hasSuffix:@"@outlook.com"] || [userEmail hasSuffix:@"@hotmail.com"]) {
        [self serviceProviderSelectAction:_outlookRadioButton];
    }
    else if([userEmail hasSuffix:@"@yahoo.com"]) {
        [self serviceProviderSelectAction:_yahooRadioButton];
    }
    else {
        return FALSE;
    }
    
    return TRUE;
}

- (void)showStep:(NSUInteger)step {
    NSView *subview = nil;
    
    if(step == 0) {
        _skipProviderSelection = NO;

        subview = _step1PanelView;
    }
    else if(step == 1) {
        if(_curStep == step - 1) {
            if(_shouldResetSelectedProvier) {
                _shouldResetSelectedProvier = NO;

                [self resetSelectedProvider];
            }
            
            if([self autoSelectServiceProvider]) {
                _skipProviderSelection = YES;
                
                [self showStep:step + 1];
                return;
            }
        }
        else if(_curStep == step + 1) {
            if(_skipProviderSelection) {
                _skipProviderSelection = NO;
                
                [self showStep:step - 1];
                return;
            }
        }
        
        subview = _step2PanelView;
    }
    else if(step == 2) {
        subview = _step3PanelView;
    }
    else {
        NSAssert(nil, @"unknown step %lu", step);
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

    _curStep = step;
    
    [self initResponderChain];
}

- (void)initResponderChain {
    if(_curStep == 0) {
        [self.window setInitialFirstResponder:_fullNameField];
        [self.window makeFirstResponder:_fullNameField];

        [_fullNameField setNextKeyView:_nextButton];
        [_nextButton setNextKeyView:_cancelButton];
        [_cancelButton setNextKeyView:_fullNameField];
    }
    else if(_curStep == 1) {
        [self.window makeFirstResponder:_gmailRadioButton];

        [_gmailRadioButton setNextKeyView:_icloudRadioButton];
        [_icloudRadioButton setNextKeyView:_outlookRadioButton];
        [_outlookRadioButton setNextKeyView:_yahooRadioButton];
        [_yahooRadioButton setNextKeyView:_customServerRadioButton];
        [_customServerRadioButton setNextKeyView:_nextButton];
        [_nextButton setNextKeyView:_backButton];
        [_backButton setNextKeyView:_cancelButton];
        [_cancelButton setNextKeyView:_gmailRadioButton];
    }
    else if(_curStep == 2) {
        [self.window makeFirstResponder:_emailAddressField];

        [_emailAddressField setNextKeyView:_passwordField];
        [_passwordField setNextKeyView:_nextButton];
        [_nextButton setNextKeyView:_backButton];
        [_backButton setNextKeyView:_cancelButton];
        [_cancelButton setNextKeyView:_emailAddressField];
    }
}

- (IBAction)serviceProviderSelectAction:(id)sender {
    NSUInteger i = 0;
    
    for(NSButton *b in _mailServiceProviderButtons) {
        if(sender == b || sender == _mailServiceProviderImageButtons[i]) {
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
        [self validateUserName:YES];
    }
    else if([obj object] == _emailAddressField) {
        _shouldResetSelectedProvier = YES;

        [self validateEmailAddress:YES];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if([[[obj userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement) {
        SM_LOG_INFO(@"enter key pressed");
    }
}

- (void)finishAccountCreation {
    NSAssert(_fullNameField.stringValue != nil && _fullNameField.stringValue.length > 0, @"no user name");
    NSAssert(_emailAddressField.stringValue != nil && _emailAddressField.stringValue.length > 0, @"no email address");
    
    SMMailServiceProvider *provider = nil;
    id selectedMailProviderButton = _mailServiceProviderButtons[_mailServiceProvierIdx];
    
    NSString *emailAddress = _emailAddressField.stringValue;
    NSAssert(emailAddress != nil, @"emailAddress is nil");
    
    NSString *password = (_passwordField.stringValue != nil? _passwordField.stringValue : nil);
    
    if(selectedMailProviderButton == _gmailRadioButton) {
        provider = [[SMMailServiceProviderGmail alloc] initWithEmailAddress:emailAddress password:password];
    }
    else if(selectedMailProviderButton == _icloudRadioButton) {
        provider = [[SMMailServiceProviderICloud alloc] initWithEmailAddress:emailAddress password:password];
    }
    else if(selectedMailProviderButton == _yahooRadioButton) {
        provider = [[SMMailServiceProviderYahoo alloc] initWithEmailAddress:emailAddress password:password];
    }
    else if(selectedMailProviderButton == _outlookRadioButton) {
        provider = [[SMMailServiceProviderOutlook alloc] initWithEmailAddress:emailAddress password:password];
    }
    else if(selectedMailProviderButton == _customServerRadioButton) {
        provider = [[SMMailServiceProviderCustom alloc] initWithEmailAddress:emailAddress password:password];
    }
    else {
        NSAssert(nil, @"bad _mailServiceProvierIdx %ld", _mailServiceProvierIdx);
    }

    NSAssert(provider != nil, @"no mail provider");
    
    NSString *accountName = _fullNameField.stringValue;

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[appDelegate preferencesController] accountExists:accountName]) {
        SM_LOG_WARNING(@"Account '%@' already exists", accountName);
        
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Account '%@' already exists, please choose another name", accountName]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert runModal];
    }
    else {
        SM_LOG_INFO(@"Account '%@' does not yet exist, creating it", accountName);

        [[appDelegate appController] closeNewAccountWindow];
        
        if(_accountImage == nil) {
            _accountImage = [SMAccountImageSelection defaultImage];
        }
        
        [[appDelegate preferencesController] addAccountWithName:accountName image:_accountImage userName:_fullNameField.stringValue emailAddress:_emailAddressField.stringValue provider:provider];
        
        [[[appDelegate appController] preferencesWindowController] reloadAccounts];

        if(![[appDelegate appController] preferencesWindowShown]) {
            [[[appDelegate appController] preferencesWindowController] showAccount:accountName];
        }

        [appDelegate addAccount];
        
        [[[appDelegate appController] accountsViewController] reloadAccountViews:YES];

        [appDelegate enableOrDisableAccountControls];
    }
}

@end
