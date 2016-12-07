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
#import "SMPreferencesWindowController.h"
#import "SMAccountsViewController.h"
#import "SMMessageListViewController.h"
#import "SMMailboxViewController.h"
#import "SMAccountImageSelection.h"
#import "SMAccountPreferencesViewController.h"
#import "SMURLChooserViewController.h"

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
@property (weak) IBOutlet NSButton *useImageFromAddressBook;
@property (weak) IBOutlet NSButton *useUnifiedMailboxButton;

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
    NSMutableArray *_accountImages;
    SMConnectionCheck *_connectionCheck;
    SMURLChooserViewController *_urlChooserViewController;
    NSWindow *_urlChooserWindow;
    BOOL _connectivityChangesWereMade;
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
    
    [self reloadAccountImages];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if([preferencesController accountsCount] > 0) {
        [self loadCurrentValues:0];
        [self togglePanel:0];
        [self checkImapConnectionAction:self];
        [self checkSmtpConnectionAction:self];
    }
    else {
        [self loadCurrentValues:-1];
        [self setAccountPanelEnabled:NO];
    }
    
    _useUnifiedMailboxButton.state = ([[appDelegate preferencesController] shouldUseUnifiedMailbox]? NSOnState : NSOffState);
    _useUnifiedMailboxButton.enabled = ([preferencesController accountsCount] > 1? YES : NO);
}

- (void)viewDidAppear {
    [self reloadAccounts];
}

- (void)viewWillDisappear {
    if(_connectivityChangesWereMade) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        SMPreferencesController *preferencesController = [appDelegate preferencesController];
        
        NSUInteger accountsCount = [preferencesController accountsCount];
        for(NSUInteger i = 0; i < accountsCount; i++) {
            [appDelegate reconnectAccount:i];
        }
    }
    
    _connectivityChangesWereMade = NO;
}

- (void)loadCurrentValues:(NSInteger)accountIdx {
    if(accountIdx >= 0) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
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
        
        _accountImageButton.image = _accountImages[accountIdx];
        
        _useImageFromAddressBook.state = ([[appDelegate preferencesController] useAddressBookAccountImage:accountIdx]? NSOnState : NSOffState);
        _useImageFromAddressBook.enabled = YES;
    }
    else {
        _accountNameField.stringValue = @"";
        _fullUserNameField.stringValue = @"";
        _emailAddressField.stringValue = @"";
        _imapServerField.stringValue = @"";
        _imapUserNameField.stringValue = @"";
        _imapPasswordField.stringValue = @"";
        
        [_imapConnectionTypeList selectItemAtIndex:-1];
        [_imapAuthTypeList selectItemAtIndex:-1];
        
        _smtpServerField.stringValue = @"";
        _smtpUserNameField.stringValue = @"";
        _smtpPasswordField.stringValue = @"";
        _imapPortField.stringValue = @"";
        _smtpPortField.stringValue = @"";
        
        [_smtpConnectionTypeList selectItemAtIndex:-1];
        [_smtpAuthTypeList selectItemAtIndex:-1];
        
        _accountImageButton.image = [SMAccountImageSelection defaultImage];
        _useImageFromAddressBook.enabled = NO;
    }
}

- (void)reloadAccountImages {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    NSUInteger accountsCount = [preferencesController accountsCount];
    _accountImages = [NSMutableArray arrayWithCapacity:accountsCount];
    
    for(NSUInteger i = 0; i < accountsCount; i++) {
        _accountImages[i] = [appDelegate.accounts[i] accountImage];
        
        if(i == [self selectedAccount]) {
            _accountImageButton.image = _accountImages[i];
        }
    }
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
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate appController] showNewAccountWindow];
    
    if(appDelegate.accounts.count != 0) {
        _removeAccountButton.enabled = YES;
    }
}

- (IBAction)removeAccountAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSString *accountName = [[appDelegate preferencesController] accountName:selectedAccount];
    
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete account %@?", accountName]];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if([alert runModal] != NSAlertFirstButtonReturn) {
        SM_LOG_DEBUG(@"Account deletion cancelled");
        return;
    }
    
    if(!appDelegate.currentAccountIsUnified && selectedAccount == appDelegate.currentAccountIdx) {
        if(selectedAccount == 0) {
            if(appDelegate.accounts.count > 1) {
                [[[appDelegate appController] accountsViewController] changeAccountTo:selectedAccount+1];
            }
            else {
                SM_LOG_INFO(@"deleting the last account");
            }
        }
        else {
            [[[appDelegate appController] accountsViewController] changeAccountTo:selectedAccount-1];
        }
    }
    else if(appDelegate.currentAccountIsUnified) {
        if(appDelegate.accounts.count == 2) {
            [[[appDelegate appController] accountsViewController] changeAccountTo:(selectedAccount == 0? 1 : 0)];
        }
        else {
            NSAssert(appDelegate.accounts.count != 1, @"unified account can't be selected if there's just one account total");
        }
    }
    
    [appDelegate removeAccount:selectedAccount];
    
    [_accountImages removeObjectAtIndex:selectedAccount];
    [_accountTableView reloadData];
    
    if(selectedAccount > 0) {
        [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedAccount-1] byExtendingSelection:NO];
        
        [self setAccountPanelEnabled:YES];
    }
    else {
        [self setAccountPanelEnabled:NO];
    }
    
    [appDelegate enableOrDisableAccountControls];
    
    [[[appDelegate appController] preferencesWindowController] reloadAccounts];
    [[[appDelegate appController] accountsViewController] reloadAccountViews:YES];
    [[[appDelegate appController] messageListViewController] reloadMessageList:NO];
}

- (IBAction)toggleAccountPanelAction:(id)sender {
    [self togglePanel:_toggleAccountSettingsPanelButton.selectedSegment];
}

#pragma mark Account settings actions

- (IBAction)selectAccountImageAction:(id)sender {
    if(_urlChooserViewController == nil) {
        _urlChooserViewController = [[SMURLChooserViewController alloc] initWithNibName:@"SMURLChooserViewController" bundle:nil];
        _urlChooserViewController.target = self;
        _urlChooserViewController.actionCancel = @selector(cancelImageUrlSelection:);
        _urlChooserViewController.actionOk = @selector(acceptImageUrlSelection:);
    }
    
    _urlChooserWindow = [[NSWindow alloc] init];
    [_urlChooserWindow setContentViewController:_urlChooserViewController];
    
    [self.view.window beginSheet:_urlChooserWindow completionHandler:nil];
    [self.view.window.sheetParent endSheet:_urlChooserWindow returnCode:NSModalResponseOK];
}

- (void)cancelImageUrlSelection:(id)sender {
    [_urlChooserWindow close];
}

- (void)acceptImageUrlSelection:(id)sender {
    [_urlChooserWindow close];
    
    NSImage *newAccountImage = _urlChooserViewController.chosenImage;
    
    if(newAccountImage != nil) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        
        NSInteger selectedAccount = [self selectedAccount];
        NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
        
        NSString *accountImagePath = [appDelegate.preferencesController accountImagePath:selectedAccount];
        NSAssert(accountImagePath != nil, @"accountImagePath is nil");
        
        [SMAccountImageSelection saveImageFile:accountImagePath image:newAccountImage];
        
        [_useImageFromAddressBook setState:NSOffState];
        [appDelegate.preferencesController setShouldUseAddressBookAccountImage:selectedAccount useAddressBookAccountImage:NO];
        
        [appDelegate reloadAccount:selectedAccount];
        
        [self reloadAccounts];
    }
}

- (IBAction)enterAccountNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    NSString *newAccountName = _accountNameField.stringValue;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([newAccountName isEqualToString:[[appDelegate preferencesController] accountName:selectedAccount]]) {
        SM_LOG_INFO(@"Account name '%@' did not change", newAccountName);
        return;
    }
    
    if(![SMPreferencesController accountNameValid:newAccountName]) {
        SM_LOG_INFO(@"Account name '%@' invalid", newAccountName);
        return;
    }
    
    if([[appDelegate preferencesController] accountExists:newAccountName]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Account '%@' already exists, please choose another name", newAccountName]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert runModal];
        
        return;
    }
    
    if(![[appDelegate preferencesController] renameAccount:selectedAccount newName:newAccountName]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot rename account to '%@', please choose another name", newAccountName]];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert runModal];
        
        return;
    }
    
    [appDelegate reloadAccount:selectedAccount];
    
    [self reloadAccounts];
}

- (IBAction)enterFullUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setFullUserName:selectedAccount userName:_fullUserNameField.stringValue];
    [appDelegate reloadAccount:selectedAccount];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterEmailAddressAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setUserEmail:selectedAccount email:_emailAddressField.stringValue];
    [appDelegate reloadAccount:selectedAccount];

    _connectivityChangesWereMade = YES;
}

- (IBAction)useImageFromAddressBookAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate.preferencesController setShouldUseAddressBookAccountImage:selectedAccount useAddressBookAccountImage:(_useImageFromAddressBook.state == NSOnState)];
    
    [appDelegate reloadAccount:selectedAccount];
    
    [self reloadAccounts];
}

- (IBAction)checkUnifiedMailboxAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    BOOL useUnifiedAccount = (_useUnifiedMailboxButton.state == NSOnState);
    
    [appDelegate preferencesController].shouldUseUnifiedMailbox = useUnifiedAccount;
    
    if(!useUnifiedAccount) {
        if(appDelegate.accountsExist && appDelegate.currentAccountIsUnified) {
            appDelegate.currentAccount = appDelegate.accounts[0];
        }
    }
    
    [[[appDelegate appController] accountsViewController] reloadAccountViews:YES];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

- (IBAction)enterImapServerAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapServer:selectedAccount server:_imapServerField.stringValue];

    _connectivityChangesWereMade = YES;
}

- (IBAction)enterImapUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapUserName:selectedAccount userName:_imapUserNameField.stringValue];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterImapPasswordAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapPassword:selectedAccount password:_imapPasswordField.stringValue];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterSmtpServerAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpServer:selectedAccount server:_smtpServerField.stringValue];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterSmtpUserNameAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpUserName:selectedAccount userName:_smtpUserNameField.stringValue];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterSmtpPasswordAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpPassword:selectedAccount password:_smtpPasswordField.stringValue];
    
    _connectivityChangesWereMade = YES;
}

#pragma mark Servers actions

- (IBAction)selectImapConnectionTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerConnectionType connectionType = [[_connectionTypeConstants objectAtIndex:[_imapConnectionTypeList indexOfSelectedItem]] unsignedIntegerValue];
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapConnectionType:selectedAccount connectionType:connectionType];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)selectImapAuthTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_imapAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapAuthType:selectedAccount authType:authType];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterImapPortAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setImapPort:selectedAccount port:(unsigned int)[_imapPortField.stringValue integerValue]];
    
    _connectivityChangesWereMade = YES;
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
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpConnectionType:selectedAccount connectionType:connectionType];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)selectSmtpAuthTypeAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    SMServerAuthType authType = [[_authTypeConstants objectAtIndex:[_smtpAuthTypeList indexOfSelectedItem]] unsignedIntegerValue];
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpAuthType:selectedAccount authType:authType];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)enterSmtpPortAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    // TODO: validate value
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate preferencesController] setSmtpPort:selectedAccount port:(unsigned int)[_smtpPortField.stringValue integerValue]];
    
    _connectivityChangesWereMade = YES;
}

- (IBAction)checkImapConnectionAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    [_imapConnectionStatusLabel setStringValue:@"Connecting..."];
    
    _imapConnectionStatusImage.hidden = YES;
    _imapConnectionProgressIndicator.hidden = NO;
    
    [_imapConnectionProgressIndicator startAnimation:self];
    
    __weak id weakSelf = self;
    [_connectionCheck checkImapConnection:selectedAccount statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        [_self processCheckImapConnectionOpResult:status mcoError:mcoError];
    }];
}

- (void)processCheckImapConnectionOpResult:(SMConnectionStatus)status mcoError:(MCOErrorCode)mcoError {
    SM_LOG_INFO(@"IMAP connection status %lu, code %lu", status, mcoError);
    
    [_imapConnectionStatusLabel setStringValue:[self connectionStatusText:status mcoError:mcoError]];
    [_imapConnectionStatusImage setImage:[self connectionStatusImage:status mcoError:mcoError]];
    
    _imapConnectionStatusImage.hidden = NO;
    _imapConnectionProgressIndicator.hidden = YES;
}

- (IBAction)checkSmtpConnectionAction:(id)sender {
    NSInteger selectedAccount = [self selectedAccount];
    NSAssert(selectedAccount >= 0, @"bad selected Account %ld", selectedAccount);
    
    [_smtpConnectionStatusLabel setStringValue:@"Connecting..."];
    
    _smtpConnectionStatusImage.hidden = YES;
    _smtpConnectionProgressIndicator.hidden = NO;
    
    [_smtpConnectionProgressIndicator startAnimation:self];
    
    __weak id weakSelf = self;
    [_connectionCheck checkSmtpConnection:selectedAccount statusBlock:^(SMConnectionStatus status, MCOErrorCode mcoError) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [_self processSmtpConnectionOpResult:status mcoError:mcoError];
    }];
}

- (void)processSmtpConnectionOpResult:(SMConnectionStatus)status mcoError:(MCOErrorCode)mcoError {
    SM_LOG_INFO(@"SMTP connection status %lu, code %lu", status, mcoError);
    
    [_smtpConnectionStatusLabel setStringValue:[self connectionStatusText:status mcoError:mcoError]];
    [_smtpConnectionStatusImage setImage:[self connectionStatusImage:status mcoError:mcoError]];
    
    _smtpConnectionStatusImage.hidden = NO;
    _smtpConnectionProgressIndicator.hidden = YES;
}

#pragma mark Account list table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    return [[appDelegate preferencesController] accountsCount];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    if(row < 0) {
        return nil;
    }
    
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"MainCell" owner:self];
    
    cellView.imageView.image = _accountImages[row];
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    cellView.textField.stringValue = [[appDelegate preferencesController] accountName:row];
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [_accountTableView selectedRow];
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(selectedRow < 0 || selectedRow >= [[appDelegate preferencesController] accountsCount]) {
        _removeAccountButton.enabled = NO;
        return;
    }
    
    [self loadCurrentValues:selectedRow];
    
    [self checkImapConnectionAction:self];
    [self checkSmtpConnectionAction:self];
    
    _removeAccountButton.enabled = YES;
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
    else {
        [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    NSUInteger accountsCount = [preferencesController accountsCount];
    
    [self setAccountPanelEnabled:(accountsCount > 0? YES : NO)];
    
    _useUnifiedMailboxButton.enabled = (accountsCount > 1? YES : NO);
    
    [self reloadAccountImages];
}

- (void)showAccount:(NSString*)accountName {
    for(NSInteger row = 0; row < [_accountTableView numberOfRows]; row++) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        NSString *accountInRow = [[appDelegate preferencesController] accountName:row];
        
        if([accountInRow isEqualToString:accountName]) {
            [_accountTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            break;
        }
    }
}

- (void)setAccountPanelEnabled:(BOOL)enabled {
    if(!enabled) {
        [self loadCurrentValues:-1];
        [self togglePanel:0];
    }
    
    _removeAccountButton.enabled = enabled;
    _toggleAccountSettingsPanelButton.enabled = enabled;
    _accountTableView.enabled = enabled;
    _toggleAccountSettingsPanelButton.enabled = enabled;
    _accountImageButton.enabled = enabled;
    _accountNameField.enabled = enabled;
    _fullUserNameField.enabled = enabled;
    _emailAddressField.enabled = enabled;
}

@end
