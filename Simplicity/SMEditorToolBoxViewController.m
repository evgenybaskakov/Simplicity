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

#pragma mark Text attrbitute actions

- (IBAction)sendAction:(id)sender {
    [_messageEditorViewController sendMessage];
}

- (IBAction)attachAction:(id)sender {
    [_messageEditorViewController attachDocument];
}

- (IBAction)setTextStyleAction:(id)sender {
    switch(_textStyleButton.selectedSegment) {
        case 0:
            [_messageEditorViewController toggleBold];
            break;
        case 1:
            [_messageEditorViewController toggleItalic];
            break;
        case 2:
            [_messageEditorViewController toggleUnderline];
            break;
    }
}

- (IBAction)toggleListAction:(id)sender {
    if(_toggleListButton.selectedSegment == 0) {
        [_messageEditorViewController toggleBullets];
    }
    else {
        [_messageEditorViewController toggleNumbering];
    }
}

- (IBAction)toggleQuoteAction:(id)sender {
    [_messageEditorViewController toggleQuote];
}

- (IBAction)shiftAction:(id)sender {
    if(_shiftButton.selectedSegment == 0) {
        [_messageEditorViewController shiftLeft];
    }
    else {
        [_messageEditorViewController shiftRight];
    }
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
