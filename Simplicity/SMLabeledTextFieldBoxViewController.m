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

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if (obj.object == _textField) {
        SM_LOG_DEBUG(@"obj.object: %@", obj);
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if (obj.object == _textField) {
        SM_LOG_DEBUG(@"obj.object: %@", obj);

        unsigned int whyEnd = [[[obj userInfo] objectForKey:@"NSTextMovement"] unsignedIntValue];
        
        if (whyEnd == NSTabTextMovement || whyEnd == NSReturnTextMovement) {
            [[[self view] window] makeFirstResponder:_textField.nextKeyView];
        }
    }
}

@end
