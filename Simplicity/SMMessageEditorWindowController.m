//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    NSString *_htmlContents;
    NSString *_subject;
    NSArray *_to;
    NSArray *_cc;
    NSArray *_bcc;
    uint32_t _draftUid;
    NSArray *_mcoAttachments;
}

- (void)initHtmlContents:(NSString*)htmlContents subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments {
    _htmlContents = htmlContents;
    _subject = subject;
    _to = to;
    _cc = cc;
    _bcc = bcc;
    _draftUid = draftUid;
    _mcoAttachments = mcoAttachments;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Window position setup
    
    [self setShouldCascadeWindows:YES];

    NSString *windowName = @"EditorWindow";
    [self.window setFrameUsingName:windowName];
    [self.window setFrameAutosaveName:windowName];
    
    // Delegate setup

    [[self window] setDelegate:self];
    
    // View setup

    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:[[self window] frame] embedded:NO draftUid:_draftUid];
    NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");

    [[self window] setContentView:_messageEditorViewController.view];
    
    [_messageEditorViewController setResponders:TRUE];
    
    // Editor setup
    
    SMEditorContentsKind editorContentsKind = kEmptyEditorContentsKind;
    
    if(_htmlContents != nil) {
        if(_draftUid == 0) {
            editorContentsKind = kUnfoldedReplyEditorContentsKind;
        }
        else {
            editorContentsKind = kUnfoldedDraftEditorContentsKind;
        }
    }
    
    [_messageEditorViewController startEditorWithHTML:_htmlContents subject:_subject to:_to cc:_cc bcc:_bcc kind:editorContentsKind mcoAttachments:_mcoAttachments];
}

#pragma mark Actions

//- (BOOL)windowShouldClose:(id)sender {
//    SM_LOG_DEBUG(@"???");
//    return YES;
//}

- (void)windowWillClose:(NSNotification *)notification {
    [_messageEditorViewController closeEditor:YES];
}

@end
