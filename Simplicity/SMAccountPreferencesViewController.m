//
//  SMAccountPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/29/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAccountPreferencesViewController.h"

@interface SMAccountPreferencesViewController ()

#pragma mark Main account settings controls

@property (weak) IBOutlet NSScrollView *accountTableView;
@property (weak) IBOutlet NSButton *addAccountButton;
@property (weak) IBOutlet NSButton *removeAccountButton;
@property (weak) IBOutlet NSSegmentedControl *toggleAccountSettingsPanelButton;
@property (weak) IBOutlet NSView *accountSettingsPanel;

#pragma mark Panel views

@property (strong) IBOutlet NSBox *serversPanelView;
@property (strong) IBOutlet NSBox *accountSettingsPanelView;

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
    // Do view setup here.
}

#pragma mark Main account settings actions

- (IBAction)addAccountAction:(id)sender {
}

- (IBAction)removeAccountAction:(id)sender {
}

- (IBAction)toggleAccountPanelAction:(id)sender {
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
