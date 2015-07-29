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

#import "SMFlippedView.h"
#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageEditorBase.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"

@implementation SMMessageEditorViewController {
    SMMessageEditorBase *_messageEditorBase;
    SMMessageEditorController *_messageEditorController;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSMutableArray *_attachmentsPanelViewConstraints;
    Boolean _attachmentsPanelShown;
}

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded {
    self = [super initWithNibName:nil bundle:nil];
    
    if(self) {
        NSView *view = [[SMFlippedView alloc] initWithFrame:frame];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self setView:view];
        
        _embedded = embedded;

        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] init];
        
        // To
        
        _toBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // Cc
        
        _ccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // Bcc
        
        _bccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
        
        // subject
        
        _subjectBoxView = [[NSBox alloc] init];

        [_subjectBoxView setBoxType:NSBoxCustom];
        [_subjectBoxView setTitlePosition:NSNoTitle];
        [_subjectBoxView setFillColor:[NSColor whiteColor]];
        
        // editor toolbox
        
        _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
        _editorToolBoxViewController.messageEditorViewController = self;
        
        // editor area
        
        _messageTextEditor = [[SMMessageEditorWebView alloc] init];
        
        // register events
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];
        
        [self initView];
    }
    
    return self;
}

- (void)initView {
    const CGFloat curWidth = self.view.frame.size.width;
    const CGFloat curHeight = self.view.frame.size.height;
    const CGFloat boxHeight = 31;

    // To

    [_toBoxViewController addControlSwitch:NSOnState target:self action:@selector(toggleFullAddressPanel:)];
    
    [self.view addSubview:_toBoxViewController.view];

    _toBoxViewController.view.frame = NSMakeRect(-1, -1, curWidth+2, boxHeight);
    _toBoxViewController.view.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;
    _toBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    // Cc
    
    [self.view addSubview:_ccBoxViewController.view];

    _ccBoxViewController.view.frame = NSMakeRect(-1, boxHeight-2, curWidth+2, boxHeight);
    _ccBoxViewController.view.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;
    _ccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    // Bcc
    
    [self.view addSubview:_bccBoxViewController.view];

    _bccBoxViewController.view.frame = NSMakeRect(-1, (boxHeight-1)*2-1, curWidth+2, boxHeight);
    _bccBoxViewController.view.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;
    _bccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;

    if(_embedded) {
        _toBoxViewController.controlSwitch.state = NSOffState;

        [self hideFullAddressPanel];
    }

    // subject
    
    [self.view addSubview:_subjectBoxView];

    _subjectBoxView.frame = NSMakeRect(-1, (boxHeight-1)*3-1, curWidth+2, boxHeight);
    _subjectBoxView.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;
    _subjectBoxView.translatesAutoresizingMaskIntoConstraints = YES;

    // editor toolbox
    
    [self.view addSubview:_editorToolBoxViewController.view];

    _editorToolBoxViewController.view.frame = NSMakeRect(-1, (boxHeight-1)*4-1, curWidth+2, _editorToolBoxViewController.view.frame.size.height);
    _editorToolBoxViewController.view.autoresizingMask = NSViewWidthSizable | NSViewMaxXMargin;
    _editorToolBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    // editor area
    
    [self.view addSubview:_messageTextEditor];
    
    _messageTextEditor.frame = NSMakeRect(-1, (boxHeight-1)*5-1, curWidth+2, curHeight - (boxHeight-1) * 5);
    _messageTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable | NSViewMaxXMargin | NSViewMaxYMargin;
    _messageTextEditor.translatesAutoresizingMaskIntoConstraints = YES;

    // Controls initialization
    
    [_toBoxViewController.label setStringValue:@"To:"];
    [_ccBoxViewController.label setStringValue:@"Cc:"];
    [_bccBoxViewController.label setStringValue:@"Bcc:"];
    
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
}

- (NSUInteger)editorFullHeight {
    NSAssert(_embedded, @"editor height is implemented for embedded mode only");
    return _toBoxViewController.view.frame.size.height + _editorToolBoxViewController.view.frame.size.height + _messageTextEditor.contentHeight - 2; // TODO: better spec. of this '2' - that's because of overlapping 'to', 'subject' and editor views
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    
    [_messageEditorController sendMessage:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];

    if(!_embedded) {
        [[[self view] window] close];
    }
}

- (void)deleteMessage {
    NSLog(@"%s: TODO - save the message to drafts", __func__);

    [self saveMessage];

    if(!_embedded) {
        [[[self view] window] close];
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"MessageEditorViewController", nil]];
    }
}

- (void)saveMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    NSString *subject = _subjectField.stringValue;
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
        NSLog(@"%s: selected text size value index %ld is out of range", __func__, index);
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

- (void)showFullAddressPanel {
/*    [self.view addSubview:_ccBoxViewController.view];
    [self.view addSubview:_bccBoxViewController.view];
    [self.view addSubview:_subjectBoxView];

    CGFloat deltaY = (_ccBoxView.bounds.size.height - 1) + (_bccBoxView.bounds.size.height - 1) + (_subjectBoxView.bounds.size.height - 1);
    CGFloat newY = _editorToolBoxView.frame.origin.y - deltaY;
    
    _editorToolBoxView.frame = NSMakeRect(_editorToolBoxView.frame.origin.x, newY, _editorToolBoxView.frame.size.width, _editorToolBoxView.frame.size.height);

    _messageTextEditor.frame = NSMakeRect(_messageTextEditor.frame.origin.x, _messageTextEditor.frame.origin.y, _messageTextEditor.frame.size.width, _messageTextEditor.frame.size.height - deltaY);
*/}

- (void)hideFullAddressPanel {
/*    CGFloat deltaY = (_ccBoxView.bounds.size.height - 1) + (_bccBoxView.bounds.size.height - 1) + (_subjectBoxView.bounds.size.height - 1);
    CGFloat newY = _editorToolBoxView.frame.origin.y + deltaY;
    
    [_ccBoxView removeFromSuperview];
    [_bccBoxView removeFromSuperview];
    [_subjectBoxView removeFromSuperview];

    _editorToolBoxView.frame = NSMakeRect(_editorToolBoxView.frame.origin.x, newY, _editorToolBoxView.frame.size.width, _editorToolBoxView.frame.size.height);

    _messageTextEditor.frame = NSMakeRect(_messageTextEditor.frame.origin.x, _messageTextEditor.frame.origin.y, _messageTextEditor.frame.size.width, _messageTextEditor.frame.size.height + deltaY);
*/}

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

- (void)closeEditor {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_messageEditorController closeEditor];
    [_messageTextEditor stopTextMonitor];
}

@end
