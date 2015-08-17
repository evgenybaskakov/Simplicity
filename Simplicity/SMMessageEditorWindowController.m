//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    NSString *_htmlContents;
    NSString *_subject;
    NSArray *_to;
    NSArray *_cc;
    NSArray *_bcc;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Delegate setup

    [[self window] setDelegate:self];
    
    // View setup

    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:[[self window] frame] embedded:NO];
    NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");

    [[self window] setContentView:_messageEditorViewController.view];
    
    // Editor setup
    
    SMEditorContentsKind editorContentsKind = (_htmlContents == nil? kEmptyEditorContentsKind : kUnfoldedReplyEditorContentsKind);
    [_messageEditorViewController startEditorWithHTML:_htmlContents subject:_subject to:_to cc:_cc bcc:_bcc kind:editorContentsKind];
}

- (void)setHtmlContents:(NSString*)htmlContents subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc {
    _htmlContents = htmlContents;
    _subject = subject;
    _to = to;
    _cc = cc;
    _bcc = bcc;
}

#pragma mark Actions

//- (BOOL)windowShouldClose:(id)sender {
//    NSLog(@"%s", __func__);
//    return YES;
//}

- (void)windowWillClose:(NSNotification *)notification {
    [_messageEditorViewController closeEditor];
}

@end
