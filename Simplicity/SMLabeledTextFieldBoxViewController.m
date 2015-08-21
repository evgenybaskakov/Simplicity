//
//  SMLabeledTextFieldBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMLabeledTextFieldBoxViewController.h"

@implementation SMLabeledTextFieldBoxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSView *view = [self view];
    
    NSAssert([view isKindOfClass:[NSBox class]], @"view not NSBox");
    
    [(NSBox*)view setBoxType:NSBoxCustom];
    [(NSBox*)view setTitlePosition:NSNoTitle];
    [(NSBox*)view setFillColor:[NSColor whiteColor]];
    [(NSBox*)view setBorderColor:[NSColor lightGrayColor]];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    SM_LOG_INFO(@"Text editiing finished");
    NSWindow *window = [_textField window];
    
    SM_LOG_INFO(@"1. firstResponder %@ (self.view %@, _tokenField %@, _textField.nextResponder) %@", window.firstResponder, self.view, _textField, _textField.nextResponder);
    
    [window makeFirstResponder:_textField.nextResponder];
    
    //  SM_LOG_INFO(@"2. firstResponder %@ (self.view %@, _tokenField %@)", window.firstResponder, self.view, _tokenField);
}

@end
