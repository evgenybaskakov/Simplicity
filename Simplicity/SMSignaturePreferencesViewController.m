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
@property (weak) IBOutlet NSPopUpButton *signatureList;
@property (weak) IBOutlet WebView *signatureEditor;

@end

@implementation SMSignaturePreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do view setup here.

    [_signatureEditor setEditable:YES];
    [_signatureEditor setEditingDelegate:self];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[appDelegate preferencesController] shouldUseSingleSignature]) {
        _useOneSignatureCheckBox.state = NSOnState;
        
        [self initSignature:YES];
    }
    else {
        _useOneSignatureCheckBox.state = NSOffState;

        [self initSignature:NO];
    }
}

- (void)viewDidDisappear {
    [self saveSignature:(_useOneSignatureCheckBox.state == NSOnState? YES : NO)];
}

- (IBAction)useSingleSignatureAction:(id)sender {
    // Save previous signature state.
    [self saveSignature:(_useOneSignatureCheckBox.state == NSOnState? NO : YES)];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    if(_useOneSignatureCheckBox.state == NSOnState) {
        [[appDelegate preferencesController] setShouldUseSingleSignature:YES];

        [self initSignature:YES];
    }
    else {
        [[appDelegate preferencesController] setShouldUseSingleSignature:NO];

        [self initSignature:NO];

        SM_LOG_WARNING(@"TODO");
    }
}

- (IBAction)accountListAction:(id)sender {
    [self saveSignature:(_useOneSignatureCheckBox.state == NSOnState? YES : NO)];

    SM_LOG_WARNING(@"TODO");
}

- (void)initSignature:(BOOL)useSingleSignature {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [_signatureList removeAllItems];
    
    if(useSingleSignature) {
        [_signatureList setEnabled:NO];

        NSString *signature = [[appDelegate preferencesController] singleSignature];
        [_signatureEditor.mainFrame loadHTMLString:(signature? signature : @"") baseURL:nil];
    }
    else {
        [_signatureList setEnabled:YES];

        [_signatureEditor.mainFrame loadHTMLString:@"" baseURL:nil];

        // TODO: add account names
        //        [_signatureList addItemWithTitle:@""];

        SM_LOG_WARNING(@"TODO");
    }
}

- (void)saveSignature:(BOOL)useSingleSignature {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(useSingleSignature) {
        NSString *signature = [(DOMHTMLElement *)[[_signatureEditor.mainFrame DOMDocument] documentElement] innerHTML];
        [[appDelegate preferencesController] setSingleSignature:signature];
    }
    else {
        SM_LOG_WARNING(@"TODO");
    }
    
    // TODO: save account specific signatures
}

@end
