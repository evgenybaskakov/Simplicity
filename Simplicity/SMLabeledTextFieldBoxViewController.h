//
//  SMLabeledTextFieldBoxViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMLabeledTokenFieldBoxView.h"

@interface SMLabeledTextFieldBoxViewController : NSViewController<NSTextFieldDelegate>

@property (strong) IBOutlet SMLabeledTokenFieldBoxView *mainView;

@property IBOutlet NSTextField *label;
@property IBOutlet NSTextField *textField;

@end
