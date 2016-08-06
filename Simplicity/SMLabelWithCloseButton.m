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
    
    _boxView.cornerRadius = 4;
    // Do view setup here.
}

- (IBAction)closeAction:(id)sender {
    id target = _target;
    
    if(target != nil) {
        [target performSelector:_action withObject:self afterDelay:0.0];
    }
}

- (void)setText:(NSString *)text {
    _text = text;
    _labelView.stringValue = text;
}

- (void)setColor:(NSColor *)color {
    _color = color;
    _boxView.fillColor = color;
}

@end
