//
//  SMSignaturePreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "SMSignaturePreferencesViewController.h"

@interface SMSignaturePreferencesViewController ()

@property (weak) IBOutlet NSButton *useOneSignatureCheckBox;
@property (weak) IBOutlet NSPopUpButton *accountList;
@property (weak) IBOutlet WebView *signatureEditor;

@end

@implementation SMSignaturePreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do view setup here.

}

- (IBAction)useOneSignatureAction:(id)sender {
}

- (IBAction)accountListAction:(id)sender {
}

@end
