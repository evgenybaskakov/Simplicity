//
//  SMAccountPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/29/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
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

@implementation SMAccountPreferencesViewController {
    NSArray *_connectionTypeStrings;
    NSArray *_connectionTypeConstants;
    NSArray *_authTypeStrings;
    NSArray *_authTypeConstants;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _connectionTypeStrings = @[
                               @"Clear text",
                               @"Clear text + TLS/SSL",
                               @"TLS/SSL",
                               ];

    _connectionTypeConstants = @[
                                 [NSNumber numberWithUnsignedInteger:SMServerConnectionType_Clear],
                                 [NSNumber numberWithUnsignedInteger:SMServerConnectionType_StartTLS],
                                 [NSNumber numberWithUnsignedInteger:SMServerConnectionType_TLS],
                                 ];

    [_imapConnectionTypeList removeAllItems];
    [_imapConnectionTypeList addItemsWithTitles:_connectionTypeStrings];

    [_smtpConnectionTypeList removeAllItems];
    [_smtpConnectionTypeList addItemsWithTitles:_connectionTypeStrings];
    
    _authTypeStrings = @[
                         @"No authentication",
                         @"CRAM-MD5",
                         @"PLAIN",
                         @"GSSAPI",
                         @"DIGEST-MD5",
                         @"LOGIN",
                         @"Secure remote password",
                         @"NTLM",
                         @"Kerberos V4",
                         @"OAuth2",
                         @"OAuth2/Outlook",
                         ];
    
    _authTypeConstants = @[
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLNone],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLCRAMMD5],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLPlain],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLGSSAPI],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLDIGESTMD5],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLLogin],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLSRP],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLNTLM],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_SASLKerberosV4],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_XOAuth2],
                           [NSNumber numberWithUnsignedInt:SMServerAuthType_XOAuth2Outlook],
                           ];

    [_imapAuthTypeList removeAllItems];
    [_imapAuthTypeList addItemsWithTitles:_authTypeStrings];

    [_smtpAuthTypeList removeAllItems];
    [_smtpAuthTypeList addItemsWithTitles:_authTypeStrings];
    
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
    
    [_imapConnectionTypeList selectItemAtIndex:[self connectionTypeIndex:[preferencesController imapConnectionType:0]]];
    [_imapAuthTypeList selectItemAtIndex:[self authTypeIndex:[preferencesController imapAuthType:0]]];

    _smtpServerField.stringValue = [preferencesController smtpServer:0];
    _smtpUserNameField.stringValue = [preferencesController smtpUserName:0];
    _smtpPasswordField.stringValue = [preferencesController smtpPassword:0];
    _imapPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController imapPort:0]];
    _smtpPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController smtpPort:0]];

    [_smtpConnectionTypeList selectItemAtIndex:[self connectionTypeIndex:[preferencesController smtpConnectionType:0]]];
    [_smtpAuthTypeList selectItemAtIndex:[self authTypeIndex:[preferencesController smtpAuthType:0]]];
}

- (NSUInteger)connectionTypeIndex:(SMServerConnectionType)connectionType {
    for(NSUInteger i = 0; i < _connectionTypeConstants.count; i++) {
        if([_connectionTypeConstants[i] unsignedIntegerValue] == connectionType) {
            return i;
        }
    }
    
    SM_LOG_ERROR(@"Unknown connectionType %lu, assuming 0", connectionType);
    return 0;
}

- (NSUInteger)authTypeIndex:(SMServerAuthType)authType {
    for(NSUInteger i = 0; i < _authTypeConstants.count; i++) {
        if([_authTypeConstants[i] unsignedIntegerValue] == authType) {
            return i;
        }
    }
    
    SM_LOG_ERROR(@"Unknown authType %lu, assuming 0", authType);
    return 0;
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
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)removeAccountAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)toggleAccountPanelAction:(id)sender {
    [self togglePanel:_toggleAccountSettingsPanelButton.selectedSegment];
}

#pragma mark Account settings actions

- (IBAction)enterAccountNameAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setAccountName:0 name:_accountNameField.stringValue];
}

- (IBAction)enterFullUserNameAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setFullUserName:0 userName:_fullUserNameField.stringValue];
}

- (IBAction)enterEmailAddressAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setUserEmail:0 email:_emailAddressField.stringValue];
}

- (IBAction)enterImapServerAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapServer:0 server:_imapServerField.stringValue];
}

- (IBAction)enterImapUserNameAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapUserName:0 userName:_imapUserNameField.stringValue];
}

- (IBAction)enterImapPasswordAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapPassword:0 password:_imapPasswordField.stringValue];
}

- (IBAction)enterSmtpServerAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpServer:0 server:_smtpServerField.stringValue];
}

- (IBAction)enterSmtpUserNameAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpUserName:0 userName:_smtpUserNameField.stringValue];
}

- (IBAction)enterSmtpPasswordAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpPassword:0 password:_smtpPasswordField.stringValue];
}

#pragma mark Servers actions

- (IBAction)selectImapConnectionTypeAction:(id)sender {
    SMServerConnectionType connectionType = [[_connectionTypeConstants objectAtIndex:[_imapConnectionTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapConnectionType:0 connectionType:connectionType];
}

- (IBAction)selectImapAuthTypeAction:(id)sender {
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_imapAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapAuthType:0 authType:authType];
}

- (IBAction)enterImapPortAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapPort:0 port:(unsigned int)[_imapPortField.stringValue integerValue]];
}

- (IBAction)checkImapConnectionAciton:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)selectSmtpConnectionTypeAction:(id)sender {
    SMServerConnectionType connectionType = [[_connectionTypeConstants objectAtIndex:[_smtpConnectionTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpConnectionType:0 connectionType:connectionType];
}

- (IBAction)selectSmtpAuthTypeAction:(id)sender {
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_smtpAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpAuthType:0 authType:authType];
}

- (IBAction)enterSmtpPortAction:(id)sender {
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpPort:0 port:(unsigned int)[_smtpPortField.stringValue integerValue]];
}

- (IBAction)checkSmtpConnectionAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

@end
