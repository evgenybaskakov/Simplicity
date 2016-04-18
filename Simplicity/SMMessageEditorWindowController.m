//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    NSString *_initialTextContent;
    Boolean _initialPlainText;
    NSString *_subject;
    NSArray *_to;
    NSArray *_cc;
    NSArray *_bcc;
    uint32_t _draftUid;
    NSArray *_mcoAttachments;
}

- (void)initHtmlContents:(NSString*)textContent plainText:(Boolean)plainText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments {
    _initialTextContent = textContent;
    _initialPlainText = plainText;
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

    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:[[self window] frame] embedded:NO draftUid:_draftUid plainText:_initialPlainText];
    NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");

    [[self window] setContentView:_messageEditorViewController.view];
    
    [_messageEditorViewController setResponders:TRUE];
    
    // Editor setup
    
    SMEditorContentsKind editorContentsKind = kEmptyEditorContentsKind;
    
    if(_initialTextContent != nil) {
        if(_draftUid == 0) {
            editorContentsKind = kUnfoldedReplyEditorContentsKind;
        }
        else {
            editorContentsKind = kUnfoldedDraftEditorContentsKind;
        }
    }
    
    [_messageEditorViewController startEditorWithHTML:_initialTextContent subject:_subject to:_to cc:_cc bcc:_bcc kind:editorContentsKind mcoAttachments:_mcoAttachments];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    
    appDelegate.htmlTextFormatMenuItem.enabled = YES;
    appDelegate.htmlTextFormatMenuItem.target = self;
    appDelegate.htmlTextFormatMenuItem.action = @selector(makeRichTextFormat:);

    appDelegate.plainTextFormatMenuItem.enabled = YES;
    appDelegate.plainTextFormatMenuItem.target = self;
    appDelegate.plainTextFormatMenuItem.action = @selector(makePlainTextFormat:);

    BOOL usePlainText = _messageEditorViewController.plainText;
    
    appDelegate.htmlTextFormatMenuItem.state = (usePlainText? NSOffState : NSOnState);
    appDelegate.plainTextFormatMenuItem.state = (usePlainText? NSOnState : NSOffState);
}

- (void)makeRichTextFormat:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

    appDelegate.htmlTextFormatMenuItem.state = NSOnState;
    appDelegate.plainTextFormatMenuItem.state = NSOffState;

    [_messageEditorViewController makeRichText];	
}

- (void)makePlainTextFormat:(id)sender {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    
    appDelegate.htmlTextFormatMenuItem.state = NSOffState;
    appDelegate.plainTextFormatMenuItem.state = NSOnState;
    
    [_messageEditorViewController makePlainText];
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
