//
//  SMURLChooserViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/30/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMURLChooserViewController.h"

@interface SMURLChooserViewController ()
@property (weak) IBOutlet NSButton *browseFileButton;
@property (weak) IBOutlet NSButton *okButton;
@property (weak) IBOutlet NSButton *cancelButton;
@end

@implementation SMURLChooserViewController

- (IBAction)urlTextFieldAction:(id)sender {
}

- (IBAction)browseFileButtonAction:(id)sender {
}

- (IBAction)okButtonAction:(id)sender {
    if(_target && _actionOk) {
        [_target performSelector:_actionOk withObject:self afterDelay:0];
    }
}

- (IBAction)cancelButtonAction:(id)sender {
    if(_target && _actionCancel) {
        [_target performSelector:_actionCancel withObject:self afterDelay:0];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

@end
