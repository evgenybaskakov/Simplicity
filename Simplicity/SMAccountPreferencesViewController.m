//
//  SMAccountPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/29/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
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
                               @"Clear",
                               @"STARTTLS",
                               @"TLS",
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
                         @"None",
                         @"CRAM-MD5",
                         @"PLAIN",
                         @"GSSAPI",
                         @"DIGEST-MD5",
                         @"LOGIN",
                         @"SRP",
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
    
    [self loadCurrentValues:0];
    [self togglePanel:0];
    
    [self checkImapConnectionAction:self];
    [self checkSmtpConnectionAction:self];
}

- (void)viewDidAppear {
    [_accountTableView reloadData];
    
    [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (void)loadCurrentValues:(NSUInteger)accountIdx {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    _accountNameField.stringValue = [preferencesController accountName:accountIdx];
    _fullUserNameField.stringValue = [preferencesController fullUserName:accountIdx];
    
    _emailAddressField.stringValue = [preferencesController userEmail:accountIdx];
    _imapServerField.stringValue = [preferencesController imapServer:accountIdx];
    _imapUserNameField.stringValue = [preferencesController imapUserName:accountIdx];
    _imapPasswordField.stringValue = [preferencesController imapPassword:accountIdx];
    
    [_imapConnectionTypeList selectItemAtIndex:[self connectionTypeIndex:[preferencesController imapConnectionType:accountIdx]]];
    [_imapAuthTypeList selectItemAtIndex:[self authTypeIndex:[preferencesController imapAuthType:accountIdx]]];
    
    _smtpServerField.stringValue = [preferencesController smtpServer:accountIdx];
    _smtpUserNameField.stringValue = [preferencesController smtpUserName:accountIdx];
    _smtpPasswordField.stringValue = [preferencesController smtpPassword:accountIdx];
    _imapPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController imapPort:accountIdx]];
    _smtpPortField.stringValue = [NSString stringWithFormat:@"%u", [preferencesController smtpPort:accountIdx]];
    
    [_smtpConnectionTypeList selectItemAtIndex:[self connectionTypeIndex:[preferencesController smtpConnectionType:accountIdx]]];
    [_smtpAuthTypeList selectItemAtIndex:[self authTypeIndex:[preferencesController smtpAuthType:accountIdx]]];
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
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] showNewAccountWindow];
}

- (IBAction)removeAccountAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);

    NSString *accountName = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:selectedAccount];

    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete account %@?", accountName]];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if([alert runModal] != NSAlertFirstButtonReturn) {
        SM_LOG_DEBUG(@"Account deletion cancelled");
        return;
    }
    
    [[[[NSApplication sharedApplication] delegate] preferencesController] removeAccount:selectedAccount];

    [_accountTableView reloadData];

    if(selectedAccount > 0) {
        [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedAccount-1] byExtendingSelection:NO];
    }
}

- (IBAction)toggleAccountPanelAction:(id)sender {
    [self togglePanel:_toggleAccountSettingsPanelButton.selectedSegment];
}

#pragma mark Account settings actions

- (IBAction)enterAccountNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setAccountName:selectedAccount name:_accountNameField.stringValue];
}

- (IBAction)enterFullUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setFullUserName:selectedAccount userName:_fullUserNameField.stringValue];
}

- (IBAction)enterEmailAddressAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setUserEmail:selectedAccount email:_emailAddressField.stringValue];
}

- (IBAction)enterImapServerAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapServer:selectedAccount server:_imapServerField.stringValue];
}

- (IBAction)enterImapUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapUserName:selectedAccount userName:_imapUserNameField.stringValue];
}

- (IBAction)enterImapPasswordAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapPassword:selectedAccount password:_imapPasswordField.stringValue];
}

- (IBAction)enterSmtpServerAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpServer:selectedAccount server:_smtpServerField.stringValue];
}

- (IBAction)enterSmtpUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpUserName:selectedAccount userName:_smtpUserNameField.stringValue];
}

- (IBAction)enterSmtpPasswordAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpPassword:selectedAccount password:_smtpPasswordField.stringValue];
}

#pragma mark Servers actions

- (IBAction)selectImapConnectionTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerConnectionType connectionType = [[_connectionTypeConstants objectAtIndex:[_imapConnectionTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapConnectionType:selectedAccount connectionType:connectionType];
}

- (IBAction)selectImapAuthTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_imapAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapAuthType:selectedAccount authType:authType];
}

- (IBAction)enterImapPortAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setImapPort:selectedAccount port:(unsigned int)[_imapPortField.stringValue integerValue]];
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
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerConnectionType connectionType = [[_connectionTypeConstants objectAtIndex:[_smtpConnectionTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpConnectionType:selectedAccount connectionType:connectionType];
}

- (IBAction)selectSmtpAuthTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_smtpAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpAuthType:selectedAccount authType:authType];
}

- (IBAction)enterSmtpPortAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    [[[[NSApplication sharedApplication] delegate] preferencesController] setSmtpPort:selectedAccount port:(unsigned int)[_smtpPortField.stringValue integerValue]];
}

- (IBAction)checkImapConnectionAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    [_imapConnectionStatusLabel setStringValue:@"Connecting..."];
    
    _imapConnectionStatusImage.hidden = YES;
    _imapConnectionProgressIndicator.hidden = NO;
    
    [_imapConnectionProgressIndicator startAnimation:self];
    
    [_connectionCheck checkImapConnection:selectedAccount statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        SM_LOG_INFO(@"IMAP connection status %lu, code %lu", status, mcoError);
        
        [_imapConnectionStatusLabel setStringValue:[self connectionStatusText:status mcoError:mcoError]];
        [_imapConnectionStatusImage setImage:[self connectionStatusImage:status mcoError:mcoError]];
        
        _imapConnectionStatusImage.hidden = NO;
        _imapConnectionProgressIndicator.hidden = YES;
    }];
}

- (IBAction)checkSmtpConnectionAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    [_smtpConnectionStatusLabel setStringValue:@"Connecting..."];
    
    _smtpConnectionStatusImage.hidden = YES;
    _smtpConnectionProgressIndicator.hidden = NO;
    
    [_smtpConnectionProgressIndicator startAnimation:self];
    
    [_connectionCheck checkSmtpConnection:selectedAccount statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        SM_LOG_INFO(@"SMTP connection status %lu, code %lu", status, mcoError);
        
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

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [_accountTableView selectedRow];
    if(selectedRow < 0 || selectedRow >= [[[[NSApplication sharedApplication] delegate] preferencesController] accountsCount]) {
        return;
    }
    
    [self loadCurrentValues:selectedRow];
    
    [self checkImapConnectionAction:self];
    [self checkSmtpConnectionAction:self];
    
    if(selectedRow == 0) {
        // TODO: temp hack for not being able to remove account 0
        _removeAccountButton.enabled = NO;
    }
    else {
        _removeAccountButton.enabled = YES;
    }
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    return;
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    return;
}

- (NSInteger)selectedAccount {
    return [_accountTableView selectedRow];
}

- (void)reloadAccounts {
    NSInteger selectedRow = [_accountTableView selectedRow];

    [_accountTableView reloadData];
    
    if(selectedRow >= 0 && selectedRow < [_accountTableView numberOfRows]) {
        [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
    }
}

- (void)showAccount:(NSString*)accountName {
    for(NSInteger row = 0; row < [_accountTableView numberOfRows]; row++) {
        NSString *accountInRow = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:row];
        
        if([accountInRow isEqualToString:accountName]) {
            [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            break;
        }
    }
}

@end
