//
//  SMLabelWithCloseButton.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/3/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLabelWithCloseButton.h"

@interface SMLabelWithCloseButton ()
@property (weak) IBOutlet NSBox *boxView;
@property (weak) IBOutlet NSTextField *labelView;
@property (weak) IBOutlet NSButton *closeButton;
@end

@implementation SMLabelWithCloseButton

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)closeAction:(id)sender {
}

- (void)setLabel:(NSString *)label {
    _labelView.stringValue = label;
}

- (void)setColor:(NSColor *)color {
    _boxView.fillColor = color;
}

@end
