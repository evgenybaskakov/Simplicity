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
#import "SMHTMLMessageEditorView.h"
#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    NSString *_initialTextContent;
    BOOL _initialPlainText;
    NSString *_subject;
    NSArray<SMAddress*> *_to;
    NSArray<SMAddress*> *_cc;
    NSArray<SMAddress*> *_bcc;
    uint32_t _draftUid;
    NSArray *_mcoAttachments;
    SMEditorContentsKind _editorKind;
}

- (void)initHtmlContents:(NSString*)textContent plainText:(BOOL)plainText subject:(NSString*)subject to:(NSArray<SMAddress*>*)to cc:(NSArray<SMAddress*>*)cc bcc:(NSArray<SMAddress*>*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments editorKind:(SMEditorContentsKind)editorKind {
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

- (void)initEditorViewController:(SMMessageEditorViewController*)messageEditorViewController {
    _messageEditorViewController = messageEditorViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Window position setup
    
    [self setShouldCascadeWindows:YES];

    // View setup
    
    BOOL existingEditor = (_messageEditorViewController != nil);

    if(!existingEditor) {
        _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithFrame:[[self window] frame] messageThreadViewController:nil draftUid:_draftUid plainText:_initialPlainText];
        NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");
    }

    [[self window] setContentViewController:_messageEditorViewController];
    
    SMEditorFocusKind focusKind = [SMHTMLMessageEditorView contentKindToFocusKind:_editorKind];
    [_messageEditorViewController setResponders:TRUE focusKind:focusKind];
    
    // Editor setup
    
    if(!existingEditor) {
        [_messageEditorViewController startEditorWithHTML:_initialTextContent subject:_subject to:_to cc:_cc bcc:_bcc kind:_editorKind mcoAttachments:_mcoAttachments];
    }
}

- (BOOL)windowShouldClose:(id)sender {
    if(sender == self.window) {
        if(![_messageEditorViewController closeEditor:YES askConfirmationIfNecessary:YES]) {
            return FALSE;
        }
    }
    
    return TRUE;
}

- (void)windowWillClose:(NSNotification *)notification {
    if(notification.object == self.window) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        
        [[appDelegate appController] closeMessageEditorWindow:self];
    }
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
