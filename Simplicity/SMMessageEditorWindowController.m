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
    [_messageEditorViewController startEditorWithHTML:_htmlContents subject:nil to:nil cc:nil bcc:nil kind:editorContentsKind];
}

- (void)setHtmlContents:(NSString*)htmlContents {
    _htmlContents = htmlContents;
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
