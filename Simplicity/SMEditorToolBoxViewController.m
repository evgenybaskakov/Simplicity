//
//  SMEditorToolBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/11/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMColorWellWithIcon.h"
#import "SMMessageEditorViewController.h"
#import "SMEditorToolBoxViewController.h"

@implementation SMEditorToolBoxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.

    
}

#pragma mark Text attrbitute actions

- (IBAction)toggleBoldAction:(id)sender {
    [_messageEditorViewController toggleBold];
}

- (IBAction)toggleItalicAction:(id)sender {
    [_messageEditorViewController toggleItalic];
}

- (IBAction)toggleUnderlineAction:(id)sender {
    [_messageEditorViewController toggleUnderline];
}

- (IBAction)toggleBulletsAction:(id)sender {
    [_messageEditorViewController toggleBullets];
}

- (IBAction)toggleNumberingAction:(id)sender {
    [_messageEditorViewController toggleNumbering];
}

- (IBAction)toggleQuoteAction:(id)sender {
    [_messageEditorViewController toggleQuote];
}

- (IBAction)shiftLeftAction:(id)sender {
    [_messageEditorViewController shiftLeft];
}

- (IBAction)shiftRightAction:(id)sender {
    [_messageEditorViewController shiftRight];
}

- (IBAction)selectFontAction:(id)sender {
    [_messageEditorViewController selectFont];
}

- (IBAction)setTextSizeAction:(id)sender {
    [_messageEditorViewController setTextSize];
}

- (IBAction)justifyTextAction:(id)sender {
    [_messageEditorViewController justifyText];
}

- (IBAction)showSourceAction:(id)sender {
    [_messageEditorViewController showSource];
}

- (IBAction)setTextForegroundColorAction:(id)sender {
    [_messageEditorViewController setTextForegroundColor];
}

- (IBAction)setTextBackgroundColorAction:(id)sender {
    [_messageEditorViewController setTextBackgroundColor];
}

@end
