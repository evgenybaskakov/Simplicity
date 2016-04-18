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
#import "SMStringUtils.h"
#import "SMAddress.h"
#import "SMUserAccount.h"
#import "SMSuggestionProvider.h"
#import "SMAddressBookController.h"
#import "SMFlippedView.h"
#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMAddressFieldViewController.h"
#import "SMLabeledPopUpListViewController.h"
#import "SMLabeledTextFieldBoxViewController.h"
#import "SMInlineButtonPanelViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMPreferencesController.h"
#import "SMMessageEditorBase.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWebView.h"
#import "SMMessageEditorViewController.h"
#import "SMPlainTextMessageEditor.h"

typedef NS_ENUM(NSUInteger, FrameAdjustment) {
    FrameAdjustment_ShowFullPanel,
    FrameAdjustment_HideFullPanel,
    FrameAdjustment_Resize,
};

static const NSUInteger EMBEDDED_MARGIN_W = 5, EMBEDDED_MARGIN_H = 3;

@interface SMMessageEditorViewController ()
@property (readonly) SMLabeledPopUpListViewController *fromBoxViewController;
@property (readonly) SMAddressFieldViewController *toBoxViewController;
@property (readonly) SMAddressFieldViewController *ccBoxViewController;
@property (readonly) SMAddressFieldViewController *bccBoxViewController;
@property (readonly) SMLabeledTextFieldBoxViewController *subjectBoxViewController;
@property (readonly) SMInlineButtonPanelViewController *foldPanelViewController;
@end

@implementation SMMessageEditorViewController {
    SMMessageEditorBase *_messageEditorBase;
    SMMessageEditorController *_messageEditorController;
    SMMessageEditorWebView *_htmlTextEditor;
    SMPlainTextMessageEditor *_plainTextEditor;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    Boolean _attachmentsPanelShown;
    NSUInteger _panelHeight;
    NSSplitView *_textAndAttachmentsSplitView;
    NSView *_innerView;
    Boolean _fullAddressPanelShown;
    NSString *_lastSubject;
    NSString *_lastFrom;
    NSArray<SMAddress*> *_lastTo;
    NSArray<SMAddress*> *_lastCc;
    NSArray<SMAddress*> *_lastBcc;
    Boolean _doNotSaveDraftOnClose;
    SMUserAccount *_lastAccount;
    Boolean _adjustingFrames;
}

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded draftUid:(uint32_t)draftUid plainText:(Boolean)plainText {
    self = [super initWithNibName:nil bundle:nil];
    
    if(self) {
        _plainText = plainText;
        
        _lastSubject = @"";
        _lastFrom = @"";
        _lastTo = @[];
        _lastCc = @[];
        _lastBcc = @[];
        
        NSView *view = [[SMFlippedView alloc] initWithFrame:frame backgroundColor:[NSColor colorWithCalibratedWhite:0.7 alpha:1.0]];
        view.translatesAutoresizingMaskIntoConstraints = YES;
        [self setView:view];
        
        _embedded = embedded;
        
        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] initWithDraftUID:draftUid];
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        
        // From
        
        _fromBoxViewController = [[SMLabeledPopUpListViewController alloc] initWithNibName:@"SMLabeledPopUpListViewController" bundle:nil];
        _fromBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _fromBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // To
        
        _toBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _toBoxViewController.suggestionProvider = [appDelegate addressBookController];
        _toBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _toBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // Cc
        
        _ccBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _ccBoxViewController.suggestionProvider = [appDelegate addressBookController];
        _ccBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _ccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // Bcc
        
        _bccBoxViewController = [[SMAddressFieldViewController alloc] initWithNibName:@"SMAddressFieldViewController" bundle:nil];
        _bccBoxViewController.suggestionProvider = [appDelegate addressBookController];
        _bccBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _bccBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // subject
        
        _subjectBoxViewController = [[SMLabeledTextFieldBoxViewController alloc] initWithNibName:@"SMLabeledTextFieldBoxViewController" bundle:nil];
        _subjectBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _subjectBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // editor toolbox
        
        _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
        _editorToolBoxViewController.messageEditorViewController = self;
        _editorToolBoxViewController.view.autoresizingMask = NSViewWidthSizable;
        _editorToolBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        // unfold panel
        
        if(embedded) {
            _foldPanelViewController = [[SMInlineButtonPanelViewController alloc] initWithNibName:@"SMInlineButtonPanelViewController" bundle:nil];
            [_foldPanelViewController setButtonTarget:self action:@selector(unfoldHiddenText:)];
            _foldPanelViewController.view.autoresizingMask = NSViewWidthSizable;
            _foldPanelViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
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
        _innerView.autoresizingMask = NSViewWidthSizable;
        _innerView.translatesAutoresizingMaskIntoConstraints = YES;
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
    _textAndAttachmentsSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _textAndAttachmentsSplitView.translatesAutoresizingMaskIntoConstraints = YES;
    
    //[_textAndAttachmentsSplitView setDelegate:self];
    [_textAndAttachmentsSplitView setVertical:NO];
    [_textAndAttachmentsSplitView setDividerStyle:NSSplitViewDividerStyleThin];

    if(_plainText) {
        [self makePlainText:YES];
    }
    else {
        [self makeHTMLText:YES];
    }
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    if(appDelegate.accounts.count > 1) {
        [_innerView addSubview:_fromBoxViewController.view];
    }
    
    [_innerView addSubview:_toBoxViewController.view];
    [_innerView addSubview:_editorToolBoxViewController.view];
    [_innerView addSubview:_textAndAttachmentsSplitView];
    
    if(_foldPanelViewController != nil) {
        [_innerView addSubview:_foldPanelViewController.view];
    }
    
    if(!_embedded) {
        [_innerView addSubview:_subjectBoxViewController.view];
    }
    
    if(!_embedded) {
        [self showFullAddressPanel:YES];
    }
    else {
        [self hideFullAddressPanel:YES];
    }
    
    // Controls initialization
    
    [_fromBoxViewController.label setStringValue:@"From:"];
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
    
    _htmlTextEditor.messageEditorBase = _messageEditorBase;
    _htmlTextEditor.editorToolBoxViewController = _editorToolBoxViewController;
    
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
    
    [_textAndAttachmentsSplitView insertArrangedSubview:_attachmentsPanelViewController.view atIndex:1];
}

- (void)viewDidLoad {
    NSAssert(nil, @"should not happen");
}

- (void)setResponders:(BOOL)force {
    NSWindow *window = [[self view] window];
    if(window == nil) {
        SM_LOG_DEBUG(@"no window yet to set responders for");
        return;
    }
    
    NSView *editorView = _plainText? _plainTextEditor : _htmlTextEditor;
    
    // Workaround: it is nearly impossible to check if the webview has focus. The first responder in that case has
    // a type of "WebHTMLView", which is a private Apple class. When the focus is on address or subject fields,
    // its type is either NSTokenTextView (subclass of NSTextView), or NSWindow.
    Boolean messageEditorFocus = ![window.firstResponder isKindOfClass:[NSWindow class]] && ![window.firstResponder isKindOfClass:[NSTextView class]];
    
    if(_fullAddressPanelShown) {
        if(!messageEditorFocus) {
            if(force) {
                [window makeFirstResponder:_subjectBoxViewController.textField];
            }
        }
        
        [window setInitialFirstResponder:_subjectBoxViewController.textField];
        
        SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
        if(appDelegate.accounts.count > 1) {
            [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
        }
        
        [_toBoxViewController.tokenField setNextKeyView:_ccBoxViewController.tokenField];
        [_ccBoxViewController.tokenField setNextKeyView:_bccBoxViewController.tokenField];
        [_bccBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
        [_subjectBoxViewController.textField setNextKeyView:editorView];
    }
    else {
        if(!_embedded) {
            if(!messageEditorFocus) {
                if(force) {
                    [window makeFirstResponder:_subjectBoxViewController.textField];
                }
            }
            
            [window setInitialFirstResponder:_subjectBoxViewController.textField];
            
            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            if(appDelegate.accounts.count > 1) {
                [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
            }
            
            [_toBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
            [_subjectBoxViewController.textField setNextKeyView:editorView];
        }
        else {
            if(!messageEditorFocus) {
                if(force) {
                    [window makeFirstResponder:_toBoxViewController.tokenField];
                }
            }
            
            [window setInitialFirstResponder:_toBoxViewController.tokenField];
            
            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            if(appDelegate.accounts.count > 1) {
                [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
            }
            
            [_toBoxViewController.tokenField setNextKeyView:editorView];
        }
    }
}


#pragma mark Editor startup

- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments {
    
    // Force the view loading for the 'from' box.
    // Otherwise the following sequence is incorrect.
    [_fromBoxViewController view];
    
    NSAssert(_fromBoxViewController.itemList != nil, @"_fromBoxViewController.itemList == nil");
    [_fromBoxViewController.itemList removeAllItems];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    for(NSUInteger i = 0, n = preferencesController.accountsCount; i < n; i++) {
        NSString *userAddressAndName = [NSString stringWithFormat:@"%@ <%@>", [preferencesController fullUserName:i], [preferencesController userEmail:i] ];
        
        [_fromBoxViewController.itemList addItemWithTitle:userAddressAndName];
        [[_fromBoxViewController.itemList itemAtIndex:i] setRepresentedObject:appDelegate.accounts[i]];
    }
    
    [_fromBoxViewController.itemList selectItemAtIndex:appDelegate.currentAccountIdx];
    
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
    
    _lastAccount = _fromBoxViewController.itemList.selectedItem.representedObject;
    _lastSubject = _subjectBoxViewController.textField.stringValue;
    _lastFrom = _fromBoxViewController.itemList.titleOfSelectedItem;
    _lastTo = _toBoxViewController.tokenField.objectValue;
    _lastCc = _ccBoxViewController.tokenField.objectValue;
    _lastBcc = _bccBoxViewController.tokenField.objectValue;
    
    Boolean sendEnabled = (to != nil && to.count != 0);
    [_editorToolBoxViewController.sendButton setEnabled:sendEnabled];
    
    [_htmlTextEditor startEditorWithHTML:messageHtmlBody kind:editorKind];
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;
    
    SMUserAccount *account = _fromBoxViewController.itemList.selectedItem.representedObject;
    if(![[[[NSApplication sharedApplication] delegate] accounts] containsObject:account]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot send message, as the chosen user account %@ does not exist.", from]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return;
    }
    NSString *messageText = [_htmlTextEditor getMessageText];
    
    [_messageEditorController sendMessage:messageText subject:_subjectBoxViewController.textField.objectValue from:[[SMAddress alloc] initWithStringRepresentation:from] to:_toBoxViewController.tokenField.objectValue cc:_ccBoxViewController.tokenField.objectValue bcc:_bccBoxViewController.tokenField.objectValue account:account];
    
    if(!_embedded) {
        [[[self view] window] close];
    }
    
    [SMNotificationsController localNotifyMessageSent:self account:account];
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
        
        [_messageEditorController deleteSavedDraft:_lastAccount];
    }
    
    _doNotSaveDraftOnClose = YES;
    
    if(_embedded) {
        [SMNotificationsController localNotifyDeleteEditedMessageDraft:self account:_lastAccount];
    }
    else {
        [[[self view] window] close];
    }
}

- (Boolean)hasUnsavedContents {
    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;
    NSArray *to = _toBoxViewController.tokenField.objectValue;
    NSArray *cc = _ccBoxViewController.tokenField.objectValue;
    NSArray *bcc = _bccBoxViewController.tokenField.objectValue;
    
    if(_htmlTextEditor.unsavedContentPending || _messageEditorController.hasUnsavedAttachments) {
        return YES;
    }
    
    if(_lastAccount != nil && _lastAccount != _fromBoxViewController.itemList.selectedItem.representedObject) {
        return YES;
    }
    
    if((_lastSubject != nil || subject != nil) && ![_lastSubject isEqualToString:subject]) {
        return YES;
    }
    
    if((_lastFrom != nil || from != nil) && ![_lastFrom isEqualToString:from]) {
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
    
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;
    SMUserAccount *account = _fromBoxViewController.itemList.selectedItem.representedObject;
    
    if(![[[[NSApplication sharedApplication] delegate] accounts] containsObject:account]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot save message, as the chosen user account %@ does not exist.", from]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return;
    }
    
    SM_LOG_INFO(@"Message has changed, a draft will be saved");
    
    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSArray *to = _toBoxViewController.tokenField.objectValue;
    NSArray *cc = _ccBoxViewController.tokenField.objectValue;
    NSArray *bcc = _bccBoxViewController.tokenField.objectValue;
    
    _lastAccount = account;
    _lastSubject = subject;
    _lastFrom = from;
    _lastTo = to;
    _lastCc = cc;
    _lastBcc = bcc;
    
    NSString *messageText = [_htmlTextEditor getMessageText];
    [_messageEditorController saveDraft:messageText subject:subject from:[[SMAddress alloc] initWithStringRepresentation:from] to:to cc:cc bcc:bcc account:account];
    
    _htmlTextEditor.unsavedContentPending = NO;
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

- (void)makeHTMLText {
    [self makeHTMLText:NO];
}

- (void)makeHTMLText:(Boolean)force {
    if(!_plainText && !force) {
        return;
    }

    CGFloat dividerPos = 0;
    BOOL restoreDividerPos = NO;
    if(_textAndAttachmentsSplitView.subviews.count == 2) {
        dividerPos = _textAndAttachmentsSplitView.subviews[0].frame.size.height;
        restoreDividerPos = YES;
    }

    if(_textAndAttachmentsSplitView.subviews.count > 0) {
        [_textAndAttachmentsSplitView.subviews[0] removeFromSuperview];
    }

    _htmlTextEditor = [[SMMessageEditorWebView alloc] init];
    _htmlTextEditor.translatesAutoresizingMaskIntoConstraints = YES;
    _htmlTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // TODO: get rid of <pre> and do it right, see issue #90
    NSString *htmlText = [NSString stringWithFormat:@"<pre>%@</pre>", _plainTextEditor.string];
    [_htmlTextEditor startEditorWithHTML:htmlText kind:kUnfoldedDraftEditorContentsKind];
    
    [_textAndAttachmentsSplitView insertArrangedSubview:_htmlTextEditor atIndex:0];
    [_textAndAttachmentsSplitView adjustSubviews];

    if(restoreDividerPos) {
        [_textAndAttachmentsSplitView setPosition:dividerPos ofDividerAtIndex:0];
    }
    
    [self setResponders:NO];

    _plainText = NO;
}

- (void)makePlainText {
    [self makePlainText:NO];
}

- (void)makePlainText:(Boolean)force {
    if(_plainText && !force) {
        return;
    }
    
    CGFloat dividerPos = 0;
    BOOL restoreDividerPos = NO;
    if(_textAndAttachmentsSplitView.subviews.count == 2) {
        dividerPos = _textAndAttachmentsSplitView.subviews[0].frame.size.height;
        restoreDividerPos = YES;
    }
    
    if(_textAndAttachmentsSplitView.subviews.count > 0) {
        [_textAndAttachmentsSplitView.subviews[0] removeFromSuperview];
    }

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];

    _plainTextEditor = [[SMPlainTextMessageEditor alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    _plainTextEditor.richText = NO;
    _plainTextEditor.verticallyResizable = YES;
    
    if(_htmlTextEditor != nil && _htmlTextEditor.mainFrame != nil) {
        _plainTextEditor.string = [(DOMHTMLElement *)[[_htmlTextEditor.mainFrame DOMDocument] documentElement] outerText];
    }
    else {
        // convert html signature to plain text
        NSString *signature = [[appDelegate preferencesController] shouldUseSingleSignature]? [[appDelegate preferencesController] singleSignature] : [[appDelegate preferencesController] accountSignature:appDelegate.currentAccountIdx];
        NSAttributedString *signatureHtmlAttributedString = [[NSAttributedString alloc] initWithData:[signature dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute:@(NSUTF8StringEncoding)} documentAttributes:nil error:nil];
        NSString *signaturePlainString = [NSString stringWithFormat:@"\n\n%@", [SMStringUtils trimString:signatureHtmlAttributedString.string]];
        
        _plainTextEditor.string = signaturePlainString;
    }
    
    _plainTextEditor.font = preferencesController.fixedMessageFont;
    _plainTextEditor.translatesAutoresizingMaskIntoConstraints = YES;
    _plainTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:_plainTextEditor.frame];
    scrollView.borderType = NSNoBorder;
    scrollView.translatesAutoresizingMaskIntoConstraints = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.documentView = _plainTextEditor;
    
    [_textAndAttachmentsSplitView insertArrangedSubview:scrollView atIndex:0];
    [_textAndAttachmentsSplitView adjustSubviews];
    
    if(restoreDividerPos) {
        [_textAndAttachmentsSplitView setPosition:dividerPos ofDividerAtIndex:0];
    }

    [self setResponders:NO];
    
    _plainText = YES;
}

- (void)toggleBold {
    [_htmlTextEditor toggleBold];
}

- (void)toggleItalic {
    [_htmlTextEditor toggleItalic];
}

- (void)toggleUnderline {
    [_htmlTextEditor toggleUnderline];
}

- (void)toggleBullets {
    [_htmlTextEditor toggleBullets];
}

- (void)toggleNumbering {
    [_htmlTextEditor toggleNumbering];
}

- (void)toggleQuote {
    [_htmlTextEditor toggleQuote];
}

- (void)shiftLeft {
    [_htmlTextEditor shiftLeft];
}

- (void)shiftRight {
    [_htmlTextEditor shiftRight];
}

- (void)selectFont {
    [_htmlTextEditor selectFont:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];
}

- (void)setTextSize {
    NSInteger index = [_editorToolBoxViewController.textSizeButton indexOfSelectedItem];
    
    if(index < 0 || index >= _editorToolBoxViewController.textSizeButton.numberOfItems) {
        SM_LOG_DEBUG(@"selected text size value index %ld is out of range", index);
        return;
    }
    
    NSInteger textSize = [[_editorToolBoxViewController.textSizeButton itemTitleAtIndex:index] integerValue];
    
    [_htmlTextEditor setTextSize:textSize];
}

- (void)justifyText {
    [_htmlTextEditor justifyText:[_editorToolBoxViewController.justifyTextControl selectedSegment]];
}

- (void)showSource {
    [_htmlTextEditor showSource];
}

- (void)setTextForegroundColor {
    [_htmlTextEditor setTextForegroundColor:_editorToolBoxViewController.textForegroundColorSelector.color];
}

- (void)setTextBackgroundColor {
    [_htmlTextEditor setTextBackgroundColor:_editorToolBoxViewController.textBackgroundColorSelector.color];
}

#pragma mark UI elements collaboration

- (void)unfoldHiddenText:(id)sender {
    NSAssert(_foldPanelViewController != nil, @"_inlineButtonPanelViewController is nil");
    
    [_htmlTextEditor unfoldContent];
    
    [_foldPanelViewController.view removeFromSuperview];
    _foldPanelViewController = nil;
    
    [self adjustFrames:FrameAdjustment_Resize];
}

- (void)toggleFullAddressPanel:(id)sender {
    NSButton *controlSwitch = _toBoxViewController.controlSwitch;
    
    if(controlSwitch.state == NSOnState) {
        [self showFullAddressPanel:NO];
    }
    else if(controlSwitch.state == NSOffState) {
        [self hideFullAddressPanel:NO];
    }
    else {
        NSAssert(false, @"unknown controlSwitch state %ld", controlSwitch.state);
    }
    
    [self setResponders:NO];
}

- (void)showFullAddressPanel:(Boolean)viewConstructionPhase {
    _fullAddressPanelShown = YES;
    
    [_innerView addSubview:_ccBoxViewController.view];
    [_innerView addSubview:_bccBoxViewController.view];
    
    if(_embedded) {
        [_innerView addSubview:_subjectBoxViewController.view];
    }
    
    [self adjustFrames:(viewConstructionPhase? FrameAdjustment_Resize : FrameAdjustment_ShowFullPanel)];
    [self notifyContentHeightChanged];
}

- (void)hideFullAddressPanel:(Boolean)viewConstructionPhase {
    _fullAddressPanelShown = NO;
    
    [_ccBoxViewController.view removeFromSuperview];
    [_bccBoxViewController.view removeFromSuperview];
    
    if(_embedded) {
        [_subjectBoxViewController.view removeFromSuperview];
    }
    
    [self adjustFrames:(viewConstructionPhase? FrameAdjustment_Resize : FrameAdjustment_HideFullPanel)];
    [self notifyContentHeightChanged];
}

- (void)notifyContentHeightChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageEditorContentHeightChanged" object:nil userInfo:nil];
}

- (void)setEditorFrame:(NSRect)frame {
    [self.view setFrame:frame];
    [self adjustFrames:FrameAdjustment_Resize];
}

- (void)adjustFrames:(FrameAdjustment)frameAdjustment {
    if(_adjustingFrames) {
        return;
    }
    
    _adjustingFrames = YES;
    
    [_innerView removeConstraints:_innerView.constraints];
    
    if(_embedded) {
        _innerView.frame = NSMakeRect(EMBEDDED_MARGIN_W, EMBEDDED_MARGIN_H, self.view.frame.size.width - EMBEDDED_MARGIN_W * 2 - 2, self.view.frame.size.height - EMBEDDED_MARGIN_H * 2 - 1);
    }
    
    const CGFloat curWidth = _innerView.frame.size.width;
    const CGFloat curHeight = _innerView.frame.size.height;
    
    CGFloat yPos = -1;
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    if(appDelegate.accounts.count > 1) {
        _fromBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _fromBoxViewController.view.frame.size.height);
        
        yPos += _fromBoxViewController.view.frame.size.height - 1;
    }
    
    _toBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _toBoxViewController.intrinsicContentViewSize.height);
    
    yPos += _toBoxViewController.intrinsicContentViewSize.height - 1;
    
    CGFloat fullAddressPanelHeight = (_ccBoxViewController.view.frame.size.height - 1) + (_bccBoxViewController.view.frame.size.height - 1);
    
    if(_fullAddressPanelShown) {
        _ccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _ccBoxViewController.intrinsicContentViewSize.height);
        
        yPos += _ccBoxViewController.view.frame.size.height - 1;
        
        _bccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _bccBoxViewController.intrinsicContentViewSize.height);
        
        yPos += _bccBoxViewController.view.frame.size.height - 1;
    }
    
    if(!_embedded || _fullAddressPanelShown) {
        _subjectBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _subjectBoxViewController.view.frame.size.height);
        
        yPos += _subjectBoxViewController.view.frame.size.height - 1;
    }
    
    if(_embedded) {
        fullAddressPanelHeight += _subjectBoxViewController.view.frame.size.height - 1;
    }
    
    _editorToolBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _editorToolBoxViewController.view.frame.size.height);
    
    yPos += _editorToolBoxViewController.view.frame.size.height; // no overlapping here, because editor view isn't bordered
    
    _panelHeight = yPos - 1;
    
    const CGFloat foldButtonHeight = (_foldPanelViewController != nil? _foldPanelViewController.view.frame.size.height : 0);
    
    CGFloat fullPanelHeightAdjustment = 0;
    if(_embedded) {
        if(frameAdjustment == FrameAdjustment_ShowFullPanel) {
            fullPanelHeightAdjustment = fullAddressPanelHeight;
        }
        else if(frameAdjustment == FrameAdjustment_HideFullPanel) {
            fullPanelHeightAdjustment = -fullAddressPanelHeight;
        }
        
        [_innerView setFrameSize:NSMakeSize(_innerView.frame.size.width, _innerView.frame.size.height + fullPanelHeightAdjustment)];
    }
    
    _textAndAttachmentsSplitView.frame = NSMakeRect(-1, yPos, curWidth+2, curHeight - yPos - foldButtonHeight + fullPanelHeightAdjustment);
    
    yPos += _textAndAttachmentsSplitView.frame.size.height;
    
    if(_foldPanelViewController != nil) {
        _foldPanelViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, foldButtonHeight);
    }
    
    _adjustingFrames = NO;
}

- (CGFloat)editorFullHeight {
    return _panelHeight + _htmlTextEditor.contentHeight + (_foldPanelViewController != nil? _foldPanelViewController.view.frame.size.height : 0) +  EMBEDDED_MARGIN_H * 2 + 2; // TODO
}

- (void)tokenFieldHeightChanged:(NSNotification*)notification {
    SMTokenField *tokenField = [[notification userInfo] objectForKey:@"Object"];
    
    if(tokenField == _toBoxViewController.tokenField || tokenField == _ccBoxViewController.tokenField || tokenField == _bccBoxViewController.tokenField) {
        [self adjustFrames:FrameAdjustment_Resize];
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
    
    [_htmlTextEditor stopTextMonitor];
}

- (void)saveDocument:(id)sender {
    [self saveMessage];
}

@end
