//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMMessageEditorView.h"
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
    SMEditorContentsKind _editorKind;
}

- (void)initHtmlContents:(NSString*)textContent plainText:(Boolean)plainText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments editorKind:(SMEditorContentsKind)editorKind {
    _initialTextContent = textContent;
    _initialPlainText = plainText;
    _subject = subject;
    _to = to;
    _cc = cc;
    _bcc = bcc;
    _draftUid = draftUid;
    _mcoAttachments = mcoAttachments;
    _editorKind = editorKind;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Window position setup
    
    [self setShouldCascadeWindows:YES];

//    NSString *windowName = @"EditorWindow";
//    [self.window setFrameUsingName:windowName];
//    [self.window setFrameAutosaveName:windowName];
    
    // Delegate setup

    [[self window] setDelegate:self];
    
    // View setup

    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:[[self window] frame] messageThreadViewController:nil draftUid:_draftUid plainText:_initialPlainText];
    NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");

    [[self window] setContentView:_messageEditorViewController.view];
    
    [_messageEditorViewController setResponders:TRUE];
    
    // Editor setup
    
    [_messageEditorViewController startEditorWithHTML:_initialTextContent subject:_subject to:_to cc:_cc bcc:_bcc kind:_editorKind mcoAttachments:_mcoAttachments];
}

- (void)windowWillClose:(NSNotification *)notification {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    [appController closeMessageEditorWindow:self];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    appController.textFormatMenuItem.enabled = YES;

    appController.htmlTextFormatMenuItem.enabled = YES;
    appController.htmlTextFormatMenuItem.target = self;
    appController.htmlTextFormatMenuItem.action = @selector(makeHTMLTextFormat:);

    appController.plainTextFormatMenuItem.enabled = YES;
    appController.plainTextFormatMenuItem.target = self;
    appController.plainTextFormatMenuItem.action = @selector(makePlainTextFormat:);

    BOOL usePlainText = _messageEditorViewController.plainText;
    
    appController.htmlTextFormatMenuItem.state = (usePlainText? NSOffState : NSOnState);
    appController.plainTextFormatMenuItem.state = (usePlainText? NSOnState : NSOffState);
}

- (void)makeHTMLTextFormat:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    appController.htmlTextFormatMenuItem.state = NSOnState;
    appController.plainTextFormatMenuItem.state = NSOffState;

    [_messageEditorViewController makeHTMLText];	
}

- (void)makePlainTextFormat:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    appController.htmlTextFormatMenuItem.state = NSOffState;
    appController.plainTextFormatMenuItem.state = NSOnState;
    
    [_messageEditorViewController makePlainText];
}

#pragma mark Actions

//- (BOOL)windowShouldClose:(id)sender {
//    SM_LOG_DEBUG(@"???");
//    return YES;
//}

@end
