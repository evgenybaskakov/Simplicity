//
//  SMMessageEditorViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <WebKit/WebUIDelegate.h>

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMFlippedView.h"
#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMLabeledTextFieldBoxViewController.h"
#import "SMInlineButtonPanelViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageEditorBase.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"

static const NSUInteger EMBEDDED_MARGIN_H = 3, EMBEDDED_MARGIN_W = 3;

@interface SMMessageEditorViewController ()
@property (readonly) SMLabeledTokenFieldBoxViewController *toBoxViewController;
@property (readonly) SMLabeledTokenFieldBoxViewController *ccBoxViewController;
@property (readonly) SMLabeledTokenFieldBoxViewController *bccBoxViewController;
@property (readonly) SMLabeledTextFieldBoxViewController *subjectBoxViewController;
@property (readonly) SMInlineButtonPanelViewController *foldPanelViewController;
@end

@implementation SMMessageEditorViewController {
    SMMessageEditorBase *_messageEditorBase;
    SMMessageEditorController *_messageEditorController;
    SMMessageEditorWebView *_messageTextEditor;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSMutableArray *_attachmentsPanelViewConstraints;
    Boolean _attachmentsPanelShown;
    NSUInteger _panelHeight;
    NSView *_innerView;
}

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded draftUid:(uint32_t)draftUid {
    self = [super initWithNibName:nil bundle:nil];
    
    if(self) {
        NSView *view = [[SMFlippedView alloc] initWithFrame:frame backgroundColor:[NSColor colorWithCalibratedRed:0.90
                                                                                                            green:0.90
                                                                                                             blue:0.90
                                                                                                            alpha:1]];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self setView:view];
        
        _embedded = embedded;

        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] initWithDraftUID:draftUid];
        
        // To
        
        _toBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // Cc
        
        _ccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];

        // Bcc
        
        _bccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // subject
        
        _subjectBoxViewController = [[SMLabeledTextFieldBoxViewController alloc] initWithNibName:@"SMLabeledTextFieldBoxViewController" bundle:nil];
        
        // editor toolbox
        
        _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
        _editorToolBoxViewController.messageEditorViewController = self;
        
        // editor area
        
        _messageTextEditor = [[SMMessageEditorWebView alloc] init];

        // unfold panel
        
        if(embedded) {
            _foldPanelViewController = [[SMInlineButtonPanelViewController alloc] initWithNibName:@"SMInlineButtonPanelViewController" bundle:nil];
            [_foldPanelViewController setButtonTarget:self action:@selector(unfoldHiddenText:)];
        }
        
        // register events
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];
        
        [self initView];
    }
    
    return self;
}

- (void)initView {
    if(_embedded) {
        _innerView = [[SMFlippedView alloc] init];
        _innerView.wantsLayer = YES;
        _innerView.layer.borderWidth = 1;
        _innerView.layer.cornerRadius = 3;
        _innerView.layer.borderColor = [[NSColor lightGrayColor] CGColor];
        
        [self.view addSubview:_innerView];
    }
    else {
        _innerView = self.view;
    }

    [_toBoxViewController addControlSwitch:(_embedded? NSOffState : NSOnState) target:self action:@selector(toggleFullAddressPanel:)];
    
    [_innerView addSubview:_toBoxViewController.view];
    [_innerView addSubview:_subjectBoxViewController.view];
    [_innerView addSubview:_editorToolBoxViewController.view];
    [_innerView addSubview:_messageTextEditor];

    if(_foldPanelViewController != nil) {
        [_innerView addSubview:_foldPanelViewController.view];
    }

    if(!_embedded) {
        [self showFullAddressPanel];
    }
    else {
        [self hideFullAddressPanel];
    }

    // Controls initialization
    
    [_toBoxViewController.label setStringValue:@"To:"];
    [_ccBoxViewController.label setStringValue:@"Cc:"];
    [_bccBoxViewController.label setStringValue:@"Bcc:"];
    [_subjectBoxViewController.label setStringValue:@"Subject:"];
    
    [_editorToolBoxViewController.sendButton setEnabled:NO];
    
    // Editor toolbox
    NSAssert(_editorToolBoxViewController != nil, @"editor toolbox is nil");
    
    [_editorToolBoxViewController.fontSelectionButton removeAllItems];
    [_editorToolBoxViewController.fontSelectionButton addItemsWithTitles:[SMMessageEditorBase fontFamilies]];
    [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:0];
    
    NSArray *textSizes = [[NSArray alloc] initWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    
    [_editorToolBoxViewController.textSizeButton removeAllItems];
    [_editorToolBoxViewController.textSizeButton addItemsWithTitles:textSizes];
    [_editorToolBoxViewController.textSizeButton selectItemAtIndex:2];
    
    _editorToolBoxViewController.textForegroundColorSelector.icon = [NSImage imageNamed:@"Editing-Text-icon.png"];
    _editorToolBoxViewController.textBackgroundColorSelector.icon = [NSImage imageNamed:@"Text-Marker.png"];
    
    // WebView post-setup
    
    _messageTextEditor.messageEditorBase = _messageEditorBase;
    _messageTextEditor.editorToolBoxViewController = _editorToolBoxViewController;
    
    // Event registration
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenFieldHeightChanged:) name:@"SMTokenFieldHeightChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moveFocusBetweenInputFields:) name:@"NSControlTextDidEndEditingNotification" object:nil];
}

- (void)viewDidLoad {
    NSAssert(nil, @"should not happen");
}

- (void)setResponders {
    NSWindow *window = [[self view] window];
    if(!window) {
        SM_LOG_DEBUG(@"no window yet");
        return;
    }

//    [_subjectBoxViewController.textField setNextKeyView:_toBoxViewController.tokenField];
//    [_subjectBoxViewController.textField setNextResponder:_toBoxViewController.tokenField];
//    [_subjectBoxViewController.view setNextKeyView:_toBoxViewController.tokenField];
//    [_subjectBoxViewController.view setNextResponder:_toBoxViewController.tokenField];
    
//    [_toBoxViewController.tokenField setNextKeyView:_ccBoxViewController.tokenField];
//    [_ccBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
//    [_bccBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];

    [window setInitialFirstResponder:_subjectBoxViewController.textField];
    [window makeFirstResponder:_subjectBoxViewController.textField];
}

- (NSResponder*)nextResponder {
    NSResponder *r = [super nextResponder];
    SM_LOG_INFO(@"r: %@, r.n: %@, r.n.n: %@", r, r.nextResponder, r.nextResponder.nextResponder);
    return r;
}

- (void)moveFocusBetweenInputFields:(NSNotification *)obj {
    SM_LOG_INFO(@"obj.object: %@", obj.object);
/*
    NSWindow *window = [[self view] window];
    NSAssert(window, @"no window");
    
    if(obj.object == _subjectBoxViewController.textField) {
        [window performSelector:@selector(makeFirstResponder:) withObject:_messageTextEditor afterDelay:0];
    }
    else if(obj.object == _toBoxViewController.tokenField || obj.object == _ccBoxViewController.tokenField || obj.object == _bccBoxViewController.tokenField)
    {
        [window performSelector:@selector(makeFirstResponder:) withObject:_subjectBoxViewController.textField afterDelay:0];
    }
*/
}

#pragma mark Editor startup

- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind {
    if(subject) {
        [_subjectBoxViewController.textField setStringValue:subject];
    }
    
    if(to) {
        [_toBoxViewController.tokenField setObjectValue:to];
    }
    
    if(cc) {
        [_ccBoxViewController.tokenField setObjectValue:cc];
    }
    
    if(bcc) {
        [_bccBoxViewController.tokenField setObjectValue:bcc];
    }
    
    [_messageTextEditor startEditorWithHTML:messageHtmlBody kind:editorKind];
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    
    [_messageEditorController sendMessage:messageText subject:_subjectBoxViewController.textField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];

    if(!_embedded) {
        [[[self view] window] close];
    }
}

- (void)deleteMessage {
    NSAlert *alert = [[NSAlert alloc] init];

    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Are you sure to delete this draft?"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if([alert runModal] != NSAlertFirstButtonReturn) {
        SM_LOG_DEBUG(@"delete cancelled");
        return;
    }
    
    if(!_embedded) {
        [[[self view] window] close];
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"MessageEditorViewController", nil]];
    }
}

- (void)saveMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSString *to = _toBoxViewController.tokenField.stringValue;
    NSString *cc = _ccBoxViewController.tokenField.stringValue;
    NSString *bcc = _bccBoxViewController.tokenField.stringValue;
    
    if(subject == nil) {
        subject = @"TODO: subject";
    }
    
    if(to == nil) {
        to = @"TODO: to";
    }
    
    if(cc == nil) {
        cc = @"TODO: cc";
    }
    
    if(bcc == nil) {
        bcc = @"TODO: bcc";
    }

    [_messageEditorController saveDraft:messageText subject:subject to:to cc:cc bcc:bcc];
}

- (void)attachDocument {
    [self toggleAttachmentsPanel];
}

#pragma mark Text attrbitute actions

- (void)toggleBold {
    [_messageTextEditor toggleBold];
}

- (void)toggleItalic {
    [_messageTextEditor toggleItalic];
}

- (void)toggleUnderline {
    [_messageTextEditor toggleUnderline];
}

- (void)toggleBullets {
    [_messageTextEditor toggleBullets];
}

- (void)toggleNumbering {
    [_messageTextEditor toggleNumbering];
}

- (void)toggleQuote {
    [_messageTextEditor toggleQuote];
}

- (void)shiftLeft {
    [_messageTextEditor shiftLeft];
}

- (void)shiftRight {
    [_messageTextEditor shiftRight];
}

- (void)selectFont {
    [_messageTextEditor selectFont:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];
}

- (void)setTextSize {
    NSInteger index = [_editorToolBoxViewController.textSizeButton indexOfSelectedItem];
    
    if(index < 0 || index >= _editorToolBoxViewController.textSizeButton.numberOfItems) {
        SM_LOG_DEBUG(@"selected text size value index %ld is out of range", index);
        return;
    }
    
    NSInteger textSize = [[_editorToolBoxViewController.textSizeButton itemTitleAtIndex:index] integerValue];
    
    [_messageTextEditor setTextSize:textSize];
}

- (void)justifyText {
    [_messageTextEditor justifyText:[_editorToolBoxViewController.justifyTextControl selectedSegment]];
}

- (void)showSource {
    [_messageTextEditor showSource];
}

- (void)setTextForegroundColor {
    [_messageTextEditor setTextForegroundColor:_editorToolBoxViewController.textForegroundColorSelector.color];
}

- (void)setTextBackgroundColor {
    [_messageTextEditor setTextBackgroundColor:_editorToolBoxViewController.textBackgroundColorSelector.color];
}

#pragma mark UI elements collaboration

- (void)unfoldHiddenText:(id)sender {
    NSAssert(_foldPanelViewController != nil, @"_inlineButtonPanelViewController is nil");

    [_messageTextEditor unfoldContent];

    [_foldPanelViewController.view removeFromSuperview];
    _foldPanelViewController = nil;

    [self adjustFrames];
}

- (void)toggleFullAddressPanel:(id)sender {
    NSButton *controlSwitch = _toBoxViewController.controlSwitch;
    
    if(controlSwitch.state == NSOnState) {
        [self showFullAddressPanel];
    }
    else if(controlSwitch.state == NSOffState) {
        [self hideFullAddressPanel];
    }
    else {
        NSAssert(false, @"unknown controlSwitch state %ld", controlSwitch.state);
    }
}

- (void)showFullAddressPanel {
    [_innerView addSubview:_ccBoxViewController.view];
    [_innerView addSubview:_bccBoxViewController.view];
    [_innerView addSubview:_subjectBoxViewController.view];
    
    [self adjustFrames];
    [self notifyContentHeightChanged];
    [self setResponders];
}

- (void)hideFullAddressPanel {
    [_ccBoxViewController.view removeFromSuperview];
    [_bccBoxViewController.view removeFromSuperview];
    [_subjectBoxViewController.view removeFromSuperview];

    [self adjustFrames];
    [self notifyContentHeightChanged];
    [self setResponders];
}

- (void)notifyContentHeightChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageEditorContentHeightChanged" object:nil userInfo:nil];
}

- (void)setEditorFrame:(NSRect)frame {
    [self.view setFrame:frame];
    [self adjustFrames];    
}

- (void)adjustFrames {
    if(_embedded) {
        _innerView.frame = NSMakeRect(EMBEDDED_MARGIN_H, EMBEDDED_MARGIN_W, self.view.frame.size.width - EMBEDDED_MARGIN_H * 2 - 1, self.view.frame.size.height - EMBEDDED_MARGIN_W * 2 - 1);
        _innerView.autoresizingMask = NSViewWidthSizable;
        _innerView.translatesAutoresizingMaskIntoConstraints = YES;
    }
    
    const CGFloat curWidth = _innerView.frame.size.width;
    const CGFloat curHeight = _innerView.frame.size.height;
    
    CGFloat yPos = -1;
    
    _toBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _toBoxViewController.intrinsicContentViewSize.height);
    _toBoxViewController.view.autoresizingMask = NSViewWidthSizable;
    _toBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    yPos += _toBoxViewController.intrinsicContentViewSize.height - 1;

    if(_toBoxViewController.controlSwitch.state == NSOnState) {
        _ccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _ccBoxViewController.intrinsicContentViewSize.height);
        _ccBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _ccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        yPos += _ccBoxViewController.view.frame.size.height - 1;
        
        _bccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _bccBoxViewController.intrinsicContentViewSize.height);
        _bccBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _bccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;

        yPos += _bccBoxViewController.view.frame.size.height - 1;

        _subjectBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _subjectBoxViewController.view.frame.size.height);
        _subjectBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _subjectBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;

        yPos += _subjectBoxViewController.view.frame.size.height - 1;
    }

    _editorToolBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _editorToolBoxViewController.view.frame.size.height);
    _editorToolBoxViewController.view.autoresizingMask = NSViewWidthSizable;
    _editorToolBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    yPos += _editorToolBoxViewController.view.frame.size.height; // no overlapping here, because editor view isn't bordered
    
    _panelHeight = yPos - 1;

    const NSUInteger foldButtonHeight = (_foldPanelViewController != nil? _foldPanelViewController.view.frame.size.height : 0);

    _messageTextEditor.frame = NSMakeRect(-1, yPos, curWidth+2, curHeight - yPos - foldButtonHeight);
    _messageTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _messageTextEditor.translatesAutoresizingMaskIntoConstraints = YES;
    
    if(_foldPanelViewController != nil) {
        _foldPanelViewController.view.frame = NSMakeRect(-1, curHeight - foldButtonHeight, curWidth+2, foldButtonHeight);
        _foldPanelViewController.view.autoresizingMask = NSViewWidthSizable;
        _foldPanelViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    }
}

- (NSUInteger)editorFullHeight {
    return _panelHeight + _messageTextEditor.contentHeight + (_foldPanelViewController != nil? _foldPanelViewController.view.frame.size.height : 0) +  EMBEDDED_MARGIN_H * 2 + 2; // TODO
}

- (void)tokenFieldHeightChanged:(NSNotification*)notification {
    SMTokenField *tokenField = [[notification userInfo] objectForKey:@"Object"];
    
    if(tokenField == _toBoxViewController.tokenField || tokenField == _ccBoxViewController.tokenField || tokenField == _bccBoxViewController.tokenField) {
        [self adjustFrames];
    }
}

- (void)processAddressFieldEditingEnd:(NSNotification*)notification {
    id object = [notification object];
    
    if(object == _toBoxViewController) {
        NSString *toValue = [[_toBoxViewController.tokenField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
        
        // TODO: verify the destination email address / recepient name more carefully
        
        [_editorToolBoxViewController.sendButton setEnabled:(toValue.length != 0)];
    }
}

#pragma mark Attachments panel

- (void)toggleAttachmentsPanel {
    if(!_attachmentsPanelShown) {
        [self showAttachmentsPanel];
    } else {
        [self hideAttachmentsPanel];
    }
}

- (void)showAttachmentsPanel {
    if(_attachmentsPanelShown)
        return;
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    if(_attachmentsPanelViewController == nil) {
        _attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
        
        NSView *attachmentsView = _attachmentsPanelViewController.view;
        NSAssert(attachmentsView, @"attachmentsView");
        
        NSAssert(_attachmentsPanelViewConstraints == nil, @"_attachmentsPanelViewConstraints already created");
        _attachmentsPanelViewConstraints = [NSMutableArray array];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageTextEditor attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewController enableEditing:_messageEditorController];
    }
    
    [view addSubview:_attachmentsPanelViewController.view];
    [view addConstraints:_attachmentsPanelViewConstraints];
    
    _attachmentsPanelShown = YES;
}

- (void)hideAttachmentsPanel {
    if(!_attachmentsPanelShown)
        return;
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    NSAssert(_attachmentsPanelViewConstraints != nil, @"_attachmentsPanelViewConstraints not created");
    [view removeConstraints:_attachmentsPanelViewConstraints];
    
    [_attachmentsPanelViewController.view removeFromSuperview];
    
    _attachmentsPanelShown = NO;
}

#pragma mark Misc

- (void)closeEditor:(Boolean)saveDraft {
    if(saveDraft) {
        [self saveMessage];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_messageTextEditor stopTextMonitor];
}

@end
