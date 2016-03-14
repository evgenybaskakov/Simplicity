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
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMAddress.h"
#import "SMSimplicityContainer.h"
#import "SMSuggestionProvider.h"
#import "SMAddressBookController.h"
#import "SMFlippedView.h"
#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMAddressFieldViewController.h"
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
@property (readonly) SMAddressFieldViewController *toBoxViewController;
@property (readonly) SMAddressFieldViewController *ccBoxViewController;
@property (readonly) SMAddressFieldViewController *bccBoxViewController;
@property (readonly) SMLabeledTextFieldBoxViewController *subjectBoxViewController;
@property (readonly) SMInlineButtonPanelViewController *foldPanelViewController;
@end

@implementation SMMessageEditorViewController {
    SMMessageEditorBase *_messageEditorBase;
    SMMessageEditorController *_messageEditorController;
    SMMessageEditorWebView *_messageTextEditor;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    Boolean _attachmentsPanelShown;
    NSUInteger _panelHeight;
    NSSplitView *_textAndAttachmentsSplitView;
    NSView *_innerView;
    Boolean _fullAddressPanelShown;
    NSString *_lastSubject;
    NSArray<SMAddress*> *_lastTo;
    NSArray<SMAddress*> *_lastCc;
    NSArray<SMAddress*> *_lastBcc;
    Boolean _doNotSaveDraftOnClose;
}

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded draftUid:(uint32_t)draftUid {
    self = [super initWithNibName:nil bundle:nil];
    
    if(self) {
        _lastSubject = @"";
        _lastTo = @[];
        _lastCc = @[];
        _lastBcc = @[];

        NSView *view = [[SMFlippedView alloc] initWithFrame:frame backgroundColor:[NSColor colorWithCalibratedRed:0.90
                                                                                                            green:0.90
                                                                                                             blue:0.90
                                                                                                            alpha:1]];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self setView:view];
        
        _embedded = embedded;

        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] initWithDraftUID:draftUid];
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

        // To
        
        _toBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _toBoxViewController.suggestionProvider = [[appDelegate model] addressBookController];
        
        // Cc
        
        _ccBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _ccBoxViewController.suggestionProvider = [[appDelegate model] addressBookController];

        // Bcc
        
        _bccBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _bccBoxViewController.suggestionProvider = [[appDelegate model] addressBookController];
        
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressFieldContentsChanged:) name:@"AddressFieldContentsChanged" object:nil];

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

    _textAndAttachmentsSplitView = [[NSSplitView alloc] init];
    
    //[_textAndAttachmentsSplitView setDelegate:self];
    [_textAndAttachmentsSplitView setVertical:NO];
    [_textAndAttachmentsSplitView setDividerStyle:NSSplitViewDividerStyleThin];
    [_textAndAttachmentsSplitView addSubview:_messageTextEditor];
    [_textAndAttachmentsSplitView adjustSubviews];
    
    [_innerView addSubview:_toBoxViewController.view];
    [_innerView addSubview:_subjectBoxViewController.view];
    [_innerView addSubview:_editorToolBoxViewController.view];
    [_innerView addSubview:_textAndAttachmentsSplitView];

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
    
    // other stuff
    
    _attachmentsPanelShown = YES;
    [self hideAttachmentsPanel];
    
    // Event registration
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenFieldHeightChanged:) name:@"SMTokenFieldHeightChanged" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)ensureAttachmentsPanelCreated {
    if(_attachmentsPanelViewController != nil) {
        SM_LOG_DEBUG(@"attachments panel already created");
        return;
    }

    _attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
    
    [_attachmentsPanelViewController enableEditing:_messageEditorController];
    [_attachmentsPanelViewController setToggleTarget:self];
    
    [_textAndAttachmentsSplitView addSubview:_attachmentsPanelViewController.view];
}

- (void)viewDidLoad {
    NSAssert(nil, @"should not happen");
}

- (void)setResponders {
    NSWindow *window = [[self view] window];
    NSAssert(window, @"no window");

    // Workaround: it is nearly impossible to check if the webview has focus. The first responder in that case has
    // a type of "WebHTMLView", which is a private Apple class. When the focus is on address or subject fields,
    // its type is either NSTokenTextView (subclass of NSTextView), or NSWindow.
    Boolean messageEditorFocus = ![window.firstResponder isKindOfClass:[NSWindow class]] && ![window.firstResponder isKindOfClass:[NSTextView class]];
    
    if(_fullAddressPanelShown) {
        if(!messageEditorFocus) {
            [window makeFirstResponder:_subjectBoxViewController.textField];
        }
        
        [window setInitialFirstResponder:_subjectBoxViewController.textField];
        
        [_toBoxViewController.tokenField setNextKeyView:_ccBoxViewController.tokenField];
        [_ccBoxViewController.tokenField setNextKeyView:_bccBoxViewController.tokenField];
        [_bccBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
        [_subjectBoxViewController.textField setNextKeyView:_messageTextEditor];
    }
    else {
        if(!messageEditorFocus) {
            [window makeFirstResponder:_toBoxViewController.tokenField];
        }
        
        [window setInitialFirstResponder:_toBoxViewController.tokenField];

        [_toBoxViewController.tokenField setNextKeyView:_messageTextEditor];
    }
}

#pragma mark Editor startup

- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments {
    
    if(subject) {
        [_subjectBoxViewController.textField setStringValue:subject];
    }
    
    if(to) {
        [_toBoxViewController.tokenField setObjectValue:[SMAddress mcoAddressesToAddressList:to]];
    }
    
    if(cc) {
        [_ccBoxViewController.tokenField setObjectValue:[SMAddress mcoAddressesToAddressList:cc]];
    }
    
    if(bcc) {
        [_bccBoxViewController.tokenField setObjectValue:[SMAddress mcoAddressesToAddressList:bcc]];
    }
    
    if(mcoAttachments != nil && mcoAttachments.count > 0) {
        [self ensureAttachmentsPanelCreated];
        
        [_attachmentsPanelViewController addMCOAttachments:mcoAttachments];
        
        [self showAttachmentsPanel];
    }
    
    _lastSubject = _subjectBoxViewController.textField.stringValue;
    _lastTo = _toBoxViewController.tokenField.objectValue;
    _lastCc = _ccBoxViewController.tokenField.objectValue;
    _lastBcc = _bccBoxViewController.tokenField.objectValue;
    
    Boolean sendEnabled = (to != nil && to.count != 0);
    [_editorToolBoxViewController.sendButton setEnabled:sendEnabled];
    
    [_messageTextEditor startEditorWithHTML:messageHtmlBody kind:editorKind];
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *messageText = [_messageTextEditor getMessageText];
    
    [_messageEditorController sendMessage:messageText subject:_subjectBoxViewController.textField.objectValue to:_toBoxViewController.tokenField.objectValue cc:_ccBoxViewController.tokenField.objectValue bcc:_bccBoxViewController.tokenField.objectValue];

    if(!_embedded) {
        [[[self view] window] close];
    }
    
    [SMNotificationsController localNotifyMessageSent:self];
}

- (void)deleteEditedDraft {
    if(self.hasUnsavedContents || _messageEditorController.hasUnsavedAttachments || _messageEditorController.hasSavedDraft) {
        NSAlert *alert = [[NSAlert alloc] init];

        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:@"Are you sure you want to delete this draft?"];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if([alert runModal] != NSAlertFirstButtonReturn) {
            SM_LOG_DEBUG(@"delete cancelled");
            return;
        }
        
        [_messageEditorController deleteSavedDraft];
    }

    _doNotSaveDraftOnClose = YES;

    if(_embedded) {
        [SMNotificationsController localNotifyDeleteEditedMessageDraft:self];
    }
    else {
        [[[self view] window] close];
    }
}

- (Boolean)hasUnsavedContents {
    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSArray *to = _toBoxViewController.tokenField.objectValue;
    NSArray *cc = _ccBoxViewController.tokenField.objectValue;
    NSArray *bcc = _bccBoxViewController.tokenField.objectValue;

    if(_messageTextEditor.unsavedContentPending || _messageEditorController.hasUnsavedAttachments) {
        return YES;
    }
    
    if((_lastSubject != nil || subject != nil) && ![_lastSubject isEqualToString:subject]) {
        return YES;
    }

    if((_lastTo != nil || to != nil) && ![_lastTo isEqualToArray:to]) {
        return YES;
    }

    if((_lastCc != nil || cc != nil) && ![_lastCc isEqualToArray:cc]) {
        return YES;
    }

    if((_lastBcc != nil || bcc != nil) && ![_lastBcc isEqualToArray:bcc]) {
        return YES;
    }

    return NO;
}

- (void)saveMessage {
    if(![self hasUnsavedContents]) {
        SM_LOG_DEBUG(@"Message contains no changes, so no save is neccessary");
        return;
    }

    SM_LOG_INFO(@"Message has changed, a draft will be saved");

    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSArray *to = _toBoxViewController.tokenField.objectValue;
    NSArray *cc = _ccBoxViewController.tokenField.objectValue;
    NSArray *bcc = _bccBoxViewController.tokenField.objectValue;
    
    _lastSubject = subject;
    _lastTo = to;
    _lastCc = cc;
    _lastBcc = bcc;
    
    NSString *messageText = [_messageTextEditor getMessageText];
    [_messageEditorController saveDraft:messageText subject:subject to:to cc:cc bcc:bcc];
    
    _messageTextEditor.unsavedContentPending = NO;
}

- (void)attachDocument {
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:YES];
    [openDlg setCanChooseDirectories:NO];
    
    [openDlg setPrompt:@"Select files to attach"];
    
    if([openDlg runModal] == NSModalResponseOK) {
        NSArray *files = [openDlg URLs];
        
        if(files && files.count > 0) {
            [self ensureAttachmentsPanelCreated];

            [_attachmentsPanelViewController addFileAttachments:files];
            
            [self showAttachmentsPanel];
        }
    }
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

    [self setResponders];
}

- (void)showFullAddressPanel {
    [_innerView addSubview:_ccBoxViewController.view];
    [_innerView addSubview:_bccBoxViewController.view];
    [_innerView addSubview:_subjectBoxViewController.view];
    
    [self adjustFrames];
    [self notifyContentHeightChanged];
    
    _fullAddressPanelShown = YES;
}

- (void)hideFullAddressPanel {
    [_ccBoxViewController.view removeFromSuperview];
    [_bccBoxViewController.view removeFromSuperview];
    [_subjectBoxViewController.view removeFromSuperview];

    [self adjustFrames];
    [self notifyContentHeightChanged];

    _fullAddressPanelShown = NO;
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

    _textAndAttachmentsSplitView.frame = NSMakeRect(-1, yPos, curWidth+2, curHeight - yPos - foldButtonHeight);
    _textAndAttachmentsSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _textAndAttachmentsSplitView.translatesAutoresizingMaskIntoConstraints = YES;
    
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

- (void)addressFieldContentsChanged:(NSNotification*)notification {
    id object = [notification object];
    
    if(object == _toBoxViewController) {
        NSString *toValue = [[_toBoxViewController.tokenField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
        
        // TODO: verify the destination email address / recepient name more carefully
        
        [_editorToolBoxViewController.sendButton setEnabled:(toValue.length != 0)];
    }
}

#pragma mark Attachments panel

- (void)toggleAttachmentsPanel:(SMAttachmentsPanelViewController*)sender {
    NSAssert(sender == _attachmentsPanelViewController, @"bad sender");
    
    [self toggleAttachmentsPanel];
}

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
    
    [self ensureAttachmentsPanelCreated];
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    [_textAndAttachmentsSplitView setPosition:(_textAndAttachmentsSplitView.frame.size.height - _attachmentsPanelViewController.uncollapsedHeight) ofDividerAtIndex:0];
    
    _attachmentsPanelShown = YES;
}

- (void)hideAttachmentsPanel {
    if(!_attachmentsPanelShown)
        return;
    
    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");
    
    [_textAndAttachmentsSplitView setPosition:(_textAndAttachmentsSplitView.frame.size.height - _attachmentsPanelViewController.collapsedHeight) ofDividerAtIndex:0];
    
    _attachmentsPanelShown = NO;
}

#pragma mark Misc

- (void)closeEditor:(Boolean)shouldSaveDraft {
    if(shouldSaveDraft && !_doNotSaveDraftOnClose) {
        [self saveMessage];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_messageTextEditor stopTextMonitor];
}

- (void)saveDocument:(id)sender {
    [self saveMessage];
}

@end
