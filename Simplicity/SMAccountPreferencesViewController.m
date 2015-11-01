//
//  SMAccountPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/29/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMAccountPreferencesViewController.h"

@interface SMAccountPreferencesViewController ()

#pragma mark Panel views

@property (strong) IBOutlet NSBox *accountSettingsPanelView;
@property (strong) IBOutlet NSBox *serversPanelView;

#pragma mark Main account settings controls

@property (weak) IBOutlet NSScrollView *accountTableView;
@property (weak) IBOutlet NSButton *addAccountButton;
@property (weak) IBOutlet NSButton *removeAccountButton;
@property (weak) IBOutlet NSSegmentedControl *toggleAccountSettingsPanelButton;
@property (weak) IBOutlet NSView *accountSettingsPanel;

#pragma mark Account settings panel

@property (weak) IBOutlet NSTextField *accountNameField;
@property (weak) IBOutlet NSTextField *fullUserNameField;
@property (weak) IBOutlet NSTextField *emailAddressField;
@property (weak) IBOutlet NSTextField *imapServerField;
@property (weak) IBOutlet NSTextField *imapUserNameField;
@property (weak) IBOutlet NSSecureTextField *imapPasswordField;
@property (weak) IBOutlet NSTextField *smtpServerField;
@property (weak) IBOutlet NSTextField *smtpUserNameField;
@property (weak) IBOutlet NSSecureTextField *smtpPasswordField;

#pragma mark Servers panel

@property (weak) IBOutlet NSPopUpButton *imapConnectionTypeList;
@property (weak) IBOutlet NSTextField *imapPortField;
@property (weak) IBOutlet NSPopUpButton *imapAuthTypeList;
@property (weak) IBOutlet NSTextField *imapConnectionStatusLabel;
@property (weak) IBOutlet NSImageView *imapConnectionStatusImage;
@property (weak) IBOutlet NSButton *imapConnectionCheckButton;
@property (weak) IBOutlet NSPopUpButton *smtpConnectionTypeList;
@property (weak) IBOutlet NSPopUpButton *smtpAuthTypeList;
@property (weak) IBOutlet NSTextField *smtpPortField;
@property (weak) IBOutlet NSTextField *smtpConnectionStatusLabel;
@property (weak) IBOutlet NSImageView *smtpConnectionStatusImage;
@property (weak) IBOutlet NSButton *smtpConnectionCheckButton;

@end

@implementation SMAccountPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setUserDefaults];
    [self togglePanel:0];
}

- (void)setUserDefaults {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    _accountNameField.stringValue = [preferencesController accountName:0];
    _fullUserNameField.stringValue = [preferencesController fullUserName:0];
    
    _emailAddressField.stringValue = [preferencesController userEmail:0];
    _imapServerField.stringValue = [preferencesController imapServer:0];
    _imapUserNameField.stringValue = [preferencesController imapUserName:0];
    _imapPasswordField.stringValue = [preferencesController imapPassword:0];
    _smtpServerField.stringValue = [preferencesController smtpServer:0];
    _smtpUserNameField.stringValue = [preferencesController smtpUserName:0];
    _smtpPasswordField.stringValue = [preferencesController smtpPassword:0];
    //NSPopUpButton *imapConnectionTypeList;
    _imapPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController imapPort:0]];
    //NSPopUpButton *imapAuthTypeList;
    //NSPopUpButton *smtpConnectionTypeList;
    //NSPopUpButton *smtpAuthTypeList;
    _smtpPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController smtpPort:0]];
}

- (void)togglePanel:(NSUInteger)panelIdx {
    NSView *panel = nil;
    
    if(panelIdx == 0) {
        panel = _accountSettingsPanelView;
    }
    else {
        panel = _serversPanelView;
    }
    
    [panel setFrameSize:_accountSettingsPanel.frame.size];
    [panel setFrameOrigin:NSMakePoint(0, 0)];
    
    [[[_accountSettingsPanel subviews] firstObject] removeFromSuperview];
    [_accountSettingsPanel addSubview:panel];
}

#pragma mark Main account settings actions

- (IBAction)addAccountAction:(id)sender {
}

- (IBAction)removeAccountAction:(id)sender {
}

- (IBAction)toggleAccountPanelAction:(id)sender {
    [self togglePanel:_toggleAccountSettingsPanelButton.selectedSegment];
}

#pragma mark Account settings actions

- (IBAction)enterAccountNameAction:(id)sender {
}

- (IBAction)enterFullUserNameAction:(id)sender {
}

- (IBAction)enterEmailAddressAction:(id)sender {
}

- (IBAction)enterImapServerAction:(id)sender {
}

- (IBAction)enterImapUserNameAction:(id)sender {
}

- (IBAction)enterImapPasswordAction:(id)sender {
}

- (IBAction)enterSmtpServerAction:(id)sender {
}

- (IBAction)enterSmtpUserNameAction:(id)sender {
}

- (IBAction)enterSmtpPasswordAction:(id)sender {
}

#pragma mark Servers actions

- (IBAction)selectImapConnectionTypeAction:(id)sender {
}

- (IBAction)selectImapAuthTypeAction:(id)sender {
}

- (IBAction)enterImapPortAction:(id)sender {
}

- (IBAction)checkImapConnectionAciton:(id)sender {
}

- (IBAction)selectSmtpConnectionTypeAction:(id)sender {
}

- (IBAction)selectSmtpAuthTypeAction:(id)sender {
}

- (IBAction)enterSmtpPortAction:(id)sender {
}

- (IBAction)checkSmtpConnectionAction:(id)sender {
}

@end
