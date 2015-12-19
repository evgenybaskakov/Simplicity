//
//  SMSignaturePreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMSignaturePreferencesViewController.h"

@interface SMSignaturePreferencesViewController ()

@property (weak) IBOutlet NSButton *useOneSignatureCheckBox;
@property (weak) IBOutlet NSPopUpButton *accountList;
@property (weak) IBOutlet WebView *signatureEditor;

@end

@implementation SMSignaturePreferencesViewController {
    NSUInteger _selectedAccount;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [_signatureEditor setEditable:YES];
    [_signatureEditor setEditingDelegate:self];

    _selectedAccount = appDelegate.currentAccount;

    if([[appDelegate preferencesController] shouldUseSingleSignature]) {
        _useOneSignatureCheckBox.state = NSOnState;
        
        [self initAccountList:YES];
        [self initSignatureEditor:YES];
    }
    else {
        _useOneSignatureCheckBox.state = NSOffState;

        [self initAccountList:NO];
        [self initSignatureEditor:NO];
    }
}

- (void)viewDidDisappear {
    [self saveSignature:(_useOneSignatureCheckBox.state == NSOnState? YES : NO)];
}

- (IBAction)useSingleSignatureAction:(id)sender {
    // Save previous signature state.
    [self saveSignature:(_useOneSignatureCheckBox.state == NSOnState? NO : YES)];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    BOOL useSingleSignature = (_useOneSignatureCheckBox.state == NSOnState);

    [[appDelegate preferencesController] setShouldUseSingleSignature:useSingleSignature];

    [self initAccountList:useSingleSignature];
    [self initSignatureEditor:useSingleSignature];
}

- (IBAction)accountListAction:(id)sender {
    BOOL useSingleSignature = (_useOneSignatureCheckBox.state == NSOnState? YES : NO);
    
    [self saveSignature:useSingleSignature];

    _selectedAccount = [_accountList indexOfSelectedItem];

    [self initSignatureEditor:useSingleSignature];
}

- (void)initAccountList:(BOOL)useSingleSignature {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [_accountList removeAllItems];
    
    if(useSingleSignature) {
        [_accountList setEnabled:NO];
    }
    else {
        [_accountList setEnabled:YES];
        
        for(NSUInteger i = 0, n = [[appDelegate preferencesController] accountsCount]; i < n; i++) {
            [_accountList addItemWithTitle:[[appDelegate preferencesController] accountName:i]];
        }
        
        [_accountList selectItemAtIndex:_selectedAccount];
    }
}

- (void)initSignatureEditor:(BOOL)useSingleSignature {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(useSingleSignature) {
        NSString *signature = [[appDelegate preferencesController] singleSignature];
        [_signatureEditor.mainFrame loadHTMLString:(signature? signature : @"") baseURL:nil];
    }
    else {
        NSString *signature = [[appDelegate preferencesController] accountSignature:_selectedAccount];
        [_signatureEditor.mainFrame loadHTMLString:signature baseURL:nil];
    }
}

- (void)saveSignature:(BOOL)useSingleSignature {
    NSString *signature = [(DOMHTMLElement *)[[_signatureEditor.mainFrame DOMDocument] documentElement] innerHTML];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(useSingleSignature) {
        [[appDelegate preferencesController] setSingleSignature:signature];
    }
    else {
        [[appDelegate preferencesController] setAccountSignature:_selectedAccount signature:signature];
    }
}

- (void)reloadAccountSignatures {
    NSString *selectedAccountName = _accountList.titleOfSelectedItem;
    BOOL useSingleSignature = (_useOneSignatureCheckBox.state == NSOnState? YES : NO);
    
    [self initAccountList:useSingleSignature];
    
    _selectedAccount = [[_accountList itemTitles] indexOfObjectIdenticalTo:selectedAccountName];
    if(_selectedAccount == NSNotFound) {
        SM_LOG_INFO(@"Account %@ disappeared, using default signature list position", selectedAccountName);
        
        _selectedAccount = 0;
    }

    [_accountList selectItemAtIndex:_selectedAccount];
    
    [self initSignatureEditor:useSingleSignature];
}

@end
