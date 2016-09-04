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
#import "SMAddress.h"
#import "SMStringUtils.h"
#import "SMAccountImageSelection.h"
#import "SMAddressBookController.h"
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
#import "SMURLChooserViewController.h"
#import "SMNewAccountWindowController.h"

static const NSUInteger LAST_STEP = 3;

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

#pragma mark Step 4

@property (strong) IBOutlet NSView *step4PanelView;
@property (weak) IBOutlet NSButton *accountImageButton;
@property (weak) IBOutlet NSTextField *existingImageFoundLabel;
@property (weak) IBOutlet NSTextField *existingImageNotFoundLabel;
@property (weak) IBOutlet NSTextField *localImageSelectedLabel;
@property (weak) IBOutlet NSTextField *accountNameField;
@property (weak) IBOutlet NSImageView *accountNameValidMarker;
@end

@implementation SMNewAccountWindowController {
    BOOL _fullNameEntered;
    BOOL _emailAddressEntered;
    BOOL _fullNameValid;
    BOOL _emailAddressValid;
    BOOL _accountNameEntered;
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
    NSImage *_userSelectedAccountImage;
    NSWindow *_urlChooserWindow;
    SMURLChooserViewController *_urlChooserViewController;
    NSString *_prevFullName;
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
    _accountNameEntered = NO;
    
    [self resetSelectedProvider];
    [self showStep:0];

    _fullNameField.stringValue = @"";
    _emailAddressField.stringValue = @"";
    _passwordField.stringValue = @"";
    _accountNameField.stringValue = @"";
    
    _fullNameInvalidMarker.hidden = YES;
    _emailInvalidMarker.hidden = YES;
    _accountNameValidMarker.hidden = YES;
    
    _userSelectedAccountImage = nil;
    _accountImage = nil;
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
        if(_prevFullName != nil && ![_prevFullName isEqualToString:_fullNameField.stringValue]) {
            _userSelectedAccountImage = nil;
        }
        
        _prevFullName = _fullNameField.stringValue;

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

- (IBAction)accountNameEnterAction:(id)sender {
    [self validateAccountName:NO];
    
    _accountNameEntered = YES;
    
    if(_accountNameValid) {
        [self.window makeFirstResponder:[(NSView*)sender nextKeyView]];
    }
}

- (IBAction)passwordEnterAction:(id)sender {
    if(_nextButton.enabled) {
        [self nextAction:self];
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

- (IBAction)accountImageButtonAction:(id)sender {
    if(_urlChooserViewController == nil) {
        _urlChooserViewController = [[SMURLChooserViewController alloc] initWithNibName:@"SMURLChooserViewController" bundle:nil];
        _urlChooserViewController.target = self;
        _urlChooserViewController.actionCancel = @selector(cancelImageUrlSelection:);
        _urlChooserViewController.actionOk = @selector(acceptImageUrlSelection:);
    }
    
    _urlChooserWindow = [[NSWindow alloc] init];
    [_urlChooserWindow setContentViewController:_urlChooserViewController];

    [self.window beginSheet:_urlChooserWindow completionHandler:nil];
    [self.window.sheetParent endSheet:_urlChooserWindow returnCode:NSModalResponseOK];
}

- (void)cancelImageUrlSelection:(id)sender {
    [_urlChooserWindow close];
}

- (void)acceptImageUrlSelection:(id)sender {
    [_urlChooserWindow close];
    
    _userSelectedAccountImage = _urlChooserViewController.chosenImage;

    [self reloadAccountImage];
}

- (void)validateUserName:(BOOL)checkFirst {
    _fullNameValid = (_fullNameField.stringValue != nil && [[SMStringUtils trimString:_fullNameField.stringValue] length] > 0)? YES : NO;

    if(checkFirst || !_fullNameEntered) {
        _fullNameInvalidMarker.hidden = (_fullNameValid? YES : NO);
    }
    
    _nextButton.enabled = (_fullNameValid? YES : NO);
}

- (void)validateEmailAddress:(BOOL)checkFirst {
    NSString *addr = [SMStringUtils trimString:_emailAddressField.stringValue];
    
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

- (void)validateAccountName:(BOOL)checkFirst {
    NSString *accountName = [SMStringUtils trimString:_accountNameField.stringValue];

    NSCharacterSet* illegalAccountNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    _accountNameValid = (accountName.length > 0) && ([accountName rangeOfCharacterFromSet:illegalAccountNameCharacters].location == NSNotFound);
    
    if(checkFirst || !_accountNameEntered) {
        _accountNameValidMarker.hidden = (_accountNameValid? YES : NO);
    }
    
    _nextButton.enabled = (_accountNameValid? YES : NO);
}

- (void)resetSelectedProvider {
    if(_mailServiceProvierIdx != NSUIntegerMax) {
        ((NSButton*)_mailServiceProviderButtons[_mailServiceProvierIdx]).state = NSOffState;
        _mailServiceProvierIdx = NSUIntegerMax;
    }
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
    else if(step == 3) {
        subview = _step4PanelView;
    }
    else {
        NSAssert(nil, @"unknown step %lu", step);
    }
    
    for(NSView *v in _stepPanelView.subviews) {
        [v removeFromSuperview];
    }
    
    [_stepPanelView addSubview:subview];
    
    subview.frame = NSMakeRect(0, 0, _stepPanelView.frame.size.width, _stepPanelView.frame.size.height);

    _nextButton.title = @"Next";

    if(step == 0) {
        _backButton.hidden = YES;
        _nextButton.hidden = NO;
        _nextButton.enabled = (_fullNameValid? YES : NO);
    }
    else if(step == 1) {
        _backButton.hidden = NO;
        _nextButton.hidden = NO;
        _nextButton.enabled = (_mailServiceProvierIdx != NSUIntegerMax);
    }
    else if(step == 2) {
        _backButton.hidden = NO;
        _nextButton.hidden = NO;
        _nextButton.enabled = (_emailAddressValid? YES : NO);
    }
    else if(step == LAST_STEP) {
        _backButton.hidden = NO;
        _nextButton.hidden = NO;
        _nextButton.title = @"Finish";
        _nextButton.enabled = (_accountNameValid? YES : NO);
        
        [self reloadAccountImage];
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
    else if(_curStep == 3) {
        [self.window makeFirstResponder:_accountNameField];
        
        [_accountNameField setNextKeyView:_nextButton];
        [_nextButton setNextKeyView:_backButton];
        [_backButton setNextKeyView:_cancelButton];
        [_cancelButton setNextKeyView:_accountNameField];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if([obj object] == _fullNameField) {
        [self validateUserName:YES];
    }
    else if([obj object] == _emailAddressField) {
        _shouldResetSelectedProvier = YES;

        [self validateEmailAddress:YES];
    }
    else if([obj object] == _accountNameField) {
        [self validateAccountName:YES];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if([[[obj userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement) {
        SM_LOG_INFO(@"enter key pressed");
    }
}

- (NSString*)getEmailAddress {
    NSString *email = [SMStringUtils trimString:_emailAddressField.stringValue];
    
    if([email rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"@"]].location == NSNotFound) {
        NSString *emailServer = _mailServiceProviderDomains[_mailServiceProvierIdx];
        
        if(emailServer.length != 0) {
            email = [NSString stringWithFormat:@"%@@%@", email, emailServer];
        }
    }
    
    return email;
}

- (void)reloadAccountImage {
    if(_userSelectedAccountImage != nil) {
        _accountImageButton.image = _userSelectedAccountImage;
        _existingImageFoundLabel.hidden = YES;
        _existingImageNotFoundLabel.hidden = YES;
        _localImageSelectedLabel.hidden = NO;
    }
    else {
        SMAddress *address = [[SMAddress alloc] initWithFullName:[SMStringUtils trimString:_fullNameField.stringValue] email:[SMStringUtils trimString:_emailAddressField.stringValue] representationMode:SMAddressRepresentation_FirstNameFirst];
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        NSImage *accountImage = [appDelegate.addressBookController loadPictureForAddress:address searchNetwork:NO allowWebSiteImage:NO tag:0 completionBlock:nil];
        
        if(accountImage) {
            _accountImageButton.image = accountImage;
            _existingImageFoundLabel.hidden = NO;
            _existingImageNotFoundLabel.hidden = YES;
        }
        else {
            _accountImageButton.image = [NSImage imageNamed:@"NSUserGuest"];
            _existingImageFoundLabel.hidden = YES;
            _existingImageNotFoundLabel.hidden = NO;
        }

        _localImageSelectedLabel.hidden = YES;
    }
}

- (void)finishAccountCreation {
    NSString *emailAddress = [self getEmailAddress];
    NSAssert(emailAddress != nil && emailAddress.length > 0, @"no email address");
    
    SMMailServiceProvider *provider = nil;
    id selectedMailProviderButton = _mailServiceProviderButtons[_mailServiceProvierIdx];
    
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
    
    NSString *accountName = [SMStringUtils trimString:_accountNameField.stringValue];
    NSAssert(accountName != nil && accountName.length > 0, @"no account name");
    
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
        
        NSString *fullUserName = [SMStringUtils trimString:_fullNameField.stringValue];
        NSAssert(fullUserName != nil && fullUserName.length > 0, @"no user name");
        
        [[appDelegate preferencesController] addAccountWithName:accountName userName:fullUserName emailAddress:emailAddress provider:provider accountImage:_userSelectedAccountImage];
        
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
