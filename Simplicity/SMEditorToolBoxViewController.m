//
//  SMEditorToolBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/11/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMColorWellWithIcon.h"
#import "SMMessageEditorWindowController.h"
#import "SMEditorToolBoxViewController.h"

@implementation SMEditorToolBoxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.

    
}

#pragma mark Text attrbitute actions

- (IBAction)toggleBoldAction:(id)sender {
    [_messageEditorWindowController toggleBold];
}

- (IBAction)toggleItalicAction:(id)sender {
    [_messageEditorWindowController toggleItalic];
}

- (IBAction)toggleUnderlineAction:(id)sender {
    [_messageEditorWindowController toggleUnderline];
}

- (IBAction)toggleBulletsAction:(id)sender {
    [_messageEditorWindowController toggleBullets];
}

- (IBAction)toggleNumberingAction:(id)sender {
    [_messageEditorWindowController toggleNumbering];
}

- (IBAction)toggleQuoteAction:(id)sender {
    [_messageEditorWindowController toggleQuote];
}

- (IBAction)shiftLeftAction:(id)sender {
    [_messageEditorWindowController shiftLeft];
}

- (IBAction)shiftRightAction:(id)sender {
    [_messageEditorWindowController shiftRight];
}

- (IBAction)selectFontAction:(id)sender {
    [_messageEditorWindowController selectFont];
}

- (IBAction)setTextSizeAction:(id)sender {
    [_messageEditorWindowController setTextSize];
}

- (IBAction)justifyTextAction:(id)sender {
    [_messageEditorWindowController justifyText];
}

- (IBAction)showSourceAction:(id)sender {
    [_messageEditorWindowController showSource];
}

- (IBAction)setTextForegroundColorAction:(id)sender {
    [_messageEditorWindowController setTextForegroundColor];
}

- (IBAction)setTextBackgroundColorAction:(id)sender {
    [_messageEditorWindowController setTextBackgroundColor];
}

@end
