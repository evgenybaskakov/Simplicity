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
    NSBox *view = (NSBox*)self.view;
    NSColor *color = [NSColor colorWithWhite:0.86 alpha:1];
    
    view.borderColor = color;

    for(NSSegmentedControl *control in @[_textStyleButton, _toggleListButton, _justifyTextControl, _shiftButton, _toggleQuoteButton]) {
        for(NSUInteger i = 0; i < control.segmentCount; i++) {
            NSImage *img = [control imageForSegment:i];
            NSSize buttonSize = [[control cell] cellSize];
            [img setSize:NSMakeSize(buttonSize.height/1.8, buttonSize.height/1.8)];
            [control setImage:img forSegment:i];
        }
    }
}

#pragma mark Text attrbitute actions

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
    if(_toggleQuoteButton.selectedSegment == 0) {
        [_messageEditorViewController toggleQuote];
    }
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
