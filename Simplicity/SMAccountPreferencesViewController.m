//
//  SMAccountPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/29/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMConnectionCheck.h"
#import "SMPreferencesController.h"
#import "SMAccountPreferencesViewController.h"

@interface SMAccountPreferencesViewController ()

#pragma mark Panel views

@property (strong) IBOutlet NSBox *generalPanelView;
@property (strong) IBOutlet NSBox *serversPanelView;
@property (strong) IBOutlet NSBox *advancedPanelView;

#pragma mark Main account settings controls

@property (weak) IBOutlet NSTableView *accountTableView;
@property (weak) IBOutlet NSButton *addAccountButton;
@property (weak) IBOutlet NSButton *removeAccountButton;
@property (weak) IBOutlet NSSegmentedControl *toggleAccountSettingsPanelButton;
@property (weak) IBOutlet NSView *accountSettingsPanel;

#pragma mark General panel

@property (weak) IBOutlet NSButton *accountImageButton;
@property (weak) IBOutlet NSTextField *accountNameField;
@property (weak) IBOutlet NSTextField *fullUserNameField;
@property (weak) IBOutlet NSTextField *emailAddressField;

#pragma mark Servers panel

@property (weak) IBOutlet NSTextField *imapServerField;
@property (weak) IBOutlet NSTextField *imapUserNameField;
@property (weak) IBOutlet NSSecureTextField *imapPasswordField;
@property (weak) IBOutlet NSTextField *smtpServerField;
@property (weak) IBOutlet NSTextField *smtpUserNameField;
@property (weak) IBOutlet NSSecureTextField *smtpPasswordField;

#pragma mark Advanced panel

@property (weak) IBOutlet NSPopUpButton *imapConnectionTypeList;
@property (weak) IBOutlet NSTextField *imapPortField;
@property (weak) IBOutlet NSPopUpButton *imapAuthTypeList;
@property (weak) IBOutlet NSTextField *imapConnectionStatusLabel;
@property (weak) IBOutlet NSImageView *imapConnectionStatusImage;
@property (weak) IBOutlet NSButton *imapConnectionCheckButton;
@property (weak) IBOutlet NSProgressIndicator *imapConnectionProgressIndicator;

@property (weak) IBOutlet NSPopUpButton *smtpConnectionTypeList;
@property (weak) IBOutlet NSPopUpButton *smtpAuthTypeList;
@property (weak) IBOutlet NSTextField *smtpPortField;
@property (weak) IBOutlet NSTextField *smtpConnectionStatusLabel;
@property (weak) IBOutlet NSImageView *smtpConnectionStatusImage;
@property (weak) IBOutlet NSButton *smtpConnectionCheckButton;
@property (weak) IBOutlet NSProgressIndicator *smtpConnectionProgressIndicator;

@end

@implementation SMAccountPreferencesViewController {
    NSArray *_connectionTypeStrings;
    NSArray *_connectionTypeConstants;
    NSArray *_authTypeStrings;
    NSArray *_authTypeConstants;
    SMConnectionCheck *_connectionCheck;
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
    
    _imapConnectionProgressIndicator.hidden = YES;
    _smtpConnectionProgressIndicator.hidden = YES;
    
    _connectionCheck = [[SMConnectionCheck alloc] init];
    
    [self loadCurrentValues];
    [self togglePanel:0];

    [self checkImapConnectionAction:self];
    [self checkSmtpConnectionAction:self];
}

- (void)loadCurrentValues {
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
    
    [_accountTableView reloadData];
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

- (NSString*)connectionErrorMessage:(MCOErrorCode)mcoError {
    NSAssert(mcoError != MCOErrorNone, @"trying to get error message for non-error");

    switch(mcoError) {
        case MCOErrorConnection:
            return @"Connection failed";
        case MCOErrorTLSNotAvailable:
            return @"TLS/SSL connection was not available";
        case MCOErrorParse:
            return @"The protocol could not be parsed";
        case MCOErrorCertificate:
            return @"Certificate invalid";
        case MCOErrorAuthentication:
            return @"Authentication failed";
        case MCOErrorGmailIMAPNotEnabled:
            return @"IMAP not enabled";
        case MCOErrorGmailExceededBandwidthLimit:
            return @"Bandwidth limit exceeded";
        case MCOErrorGmailTooManySimultaneousConnections:
            return @"Too many simultaneous connections";
        case MCOErrorMobileMeMoved:
            return @"Mobile Me is offline";
        case MCOErrorYahooUnavailable:
            return @"Yahoo is not available";
        case MCOErrorCapability:
            return @"IMAP: Error while getting capabilities";
        case MCOErrorStartTLSNotAvailable:
            return @"STARTTLS is not available";
        case MCOErrorNeedsConnectToWebmail:
            return @"Hotmail: Needs to connect to webmail";
        case MCOErrorAuthenticationRequired:
            return @"Authentication required";
        case MCOErrorInvalidAccount:
            return @"Account check error";
        case MCOErrorCompression:
            return @"Compression enabling error";
        case MCOErrorNoop:
            return @"Noop operation failed";
        case MCOErrorGmailApplicationSpecificPasswordRequired:
            return @"Second factor authentication failed";
        case MCOErrorServerDate:
            return @"NNTP date requesting error";
        case MCOErrorNoValidServerFound:
            return @"No valid server found";
        default:
            return [NSString stringWithFormat:@"Unknown connection error %lu", mcoError];
    };
}

- (void)togglePanel:(NSUInteger)panelIdx {
    NSView *panel = nil;
    
    if(panelIdx == 0) {
        panel = _generalPanelView;
    }
    else if(panelIdx == 1) {
        panel = _serversPanelView;
    }
    else {
        panel = _advancedPanelView;
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

- (NSString*)connectionStatusText:(SMConnectionStatus)status mcoError:(MCOErrorCode)mcoError {
    switch(status) {
        case SMConnectionStatus_NotConnected:
            return @"Not connected";
            
        case SMConnectionStatus_Connected:
            return @"Connected";
            
        case SMConnectionStatus_ConnectionFailed:
            return [self connectionErrorMessage:mcoError];
            
        default:
            NSAssert(nil, @"Unknown status %lu", status);
            return nil;
    }
}

- (NSImage*)connectionStatusImage:(SMConnectionStatus)status mcoError:(MCOErrorCode)mcoError {
    switch(status) {
        case SMConnectionStatus_NotConnected:
            return [NSImage imageNamed:NSImageNameStatusNone];
            
        case SMConnectionStatus_Connected:
            return [NSImage imageNamed:NSImageNameStatusAvailable];
            
        case SMConnectionStatus_ConnectionFailed:
            return [NSImage imageNamed:NSImageNameStatusUnavailable];
            
        default:
            NSAssert(nil, @"Unknown status %lu", status);
            return nil;
    }
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

- (IBAction)checkImapConnectionAction:(id)sender {
    [_imapConnectionStatusLabel setStringValue:@"Connecting..."];

    _imapConnectionStatusImage.hidden = YES;
    _imapConnectionProgressIndicator.hidden = NO;
    
    [_imapConnectionProgressIndicator startAnimation:self];
    
    [_connectionCheck checkImapConnection:0 statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        SM_LOG_INFO(@"IMAP connection status %lu, error %lu", status, mcoError);
        
        [_imapConnectionStatusLabel setStringValue:[self connectionStatusText:status mcoError:mcoError]];
        [_imapConnectionStatusImage setImage:[self connectionStatusImage:status mcoError:mcoError]];
        
        _imapConnectionStatusImage.hidden = NO;
        _imapConnectionProgressIndicator.hidden = YES;
    }];
}

- (IBAction)checkSmtpConnectionAction:(id)sender {
    [_smtpConnectionStatusLabel setStringValue:@"Connecting..."];
    
    _smtpConnectionStatusImage.hidden = YES;
    _smtpConnectionProgressIndicator.hidden = NO;
    
    [_smtpConnectionProgressIndicator startAnimation:self];
    
    [_connectionCheck checkSmtpConnection:0 statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        SM_LOG_INFO(@"SMTP connection status %lu, error %lu", status, mcoError);
        
        [_smtpConnectionStatusLabel setStringValue:[self connectionStatusText:status mcoError:mcoError]];
        [_smtpConnectionStatusImage setImage:[self connectionStatusImage:status mcoError:mcoError]];
        
        _smtpConnectionStatusImage.hidden = NO;
        _smtpConnectionProgressIndicator.hidden = YES;
    }];
}

#pragma mark Account list table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[[[NSApplication sharedApplication] delegate] preferencesController] accountsCount];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    if(row < 0) {
        return nil;
    }
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"MainCell" owner:self];
    
    cellView.imageView.image = _accountImageButton.image;
    cellView.textField.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:row];
    
    return cellView;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    return;
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    return;
}

@end
