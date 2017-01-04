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
#import "SMMessage.h"
#import "SMUserAccount.h"
#import "SMSuggestionProvider.h"
#import "SMAddressBookController.h"
#import "SMMessageThreadViewController.h"
#import "SMFlippedView.h"
#import "SMTokenField.h"
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMMessageEditorToolbarViewController.h"
#import "SMEditorFindContentsPanelViewController.h"
#import "SMAddressFieldViewController.h"
#import "SMLabeledPopUpListViewController.h"
#import "SMLabeledTextFieldBoxViewController.h"
#import "SMInlineButtonPanelViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMPreferencesController.h"
#import "SMMessageEditorBase.h"
#import "SMMessageEditorController.h"
#import "SMHTMLMessageEditorView.h"
#import "SMMessageEditorViewController.h"
#import "SMPlainTextMessageEditor.h"

typedef NS_ENUM(NSUInteger, FrameAdjustment) {
    FrameAdjustment_ShowFullPanel,
    FrameAdjustment_HideFullPanel,
    FrameAdjustment_Resize,
};

typedef NS_ENUM(NSUInteger, EditorConversion) {
    EditorConversion_Direct,
    EditorConversion_Undo,
    EditorConversion_Redo,
};

static const NSUInteger EMBEDDED_MARGIN_W = 5, EMBEDDED_MARGIN_H = 3;

@interface SMMessageEditorViewController ()
@property (readonly, nonatomic) BOOL embedded;
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
    SMHTMLMessageEditorView *_htmlTextEditor;
    SMPlainTextMessageEditor *_plainTextEditor;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMMessageEditorToolbarViewController *_messageEditorToolbarViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    SMEditorFindContentsPanelViewController *_findContentsPanelViewController;
    NSMutableArray<NSView*> *_editorsUndoList;
    NSUInteger _editorUndoLevel;
    BOOL _attachmentsPanelShown;
    NSUInteger _panelHeight;
    NSSplitView *_textAndAttachmentsSplitView;
    NSView *_innerView;
    BOOL _fullAddressPanelShown;
    NSString *_lastSubject;
    NSString *_lastFrom;
    NSArray<SMAddress*> *_lastTo;
    NSArray<SMAddress*> *_lastCc;
    NSArray<SMAddress*> *_lastBcc;
    BOOL _doNotSaveDraftOnClose;
    SMUserAccount *_lastAccount;
    BOOL _adjustingFrames;
    BOOL _savedOnce;
    BOOL _findContentsPanelShown;
    NSString *_currentStringToFind;
    BOOL _currentStringToFindMatchCase;
    BOOL _findContentsActive;
    BOOL _stringOccurrenceMarked;
    NSUInteger _stringOccurrenceMarkedResultIndex;
    BOOL _editorStateInitialized;
}

+ (void)getReplyAddressLists:(SMMessage*)message replyKind:(SMEditorReplyKind)replyKind accountAddress:(SMAddress*)accountAddress to:(NSArray<SMAddress*>**)to cc:(NSArray<SMAddress*>**)cc {
    NSMutableArray<SMAddress*> *toAddressList = nil;
    NSMutableArray<SMAddress*> *ccAddressList = nil;
    
    toAddressList = [@[message.fromAddress] mutableCopy];

    if(replyKind == SMEditorReplyKind_ReplyAll) {
        ccAddressList = [[SMAddress mcoAddressesToAddressList:message.ccAddressList] mutableCopy];

        if([message.fromAddress isEqual:accountAddress]) {
            [toAddressList addObjectsFromArray:[SMAddress mcoAddressesToAddressList:message.toAddressList]];
        }
        else {
            [ccAddressList addObjectsFromArray:[SMAddress mcoAddressesToAddressList:message.toAddressList]];
        }
        
        [toAddressList removeObject:accountAddress];
        if(toAddressList.count == 0) {
            toAddressList = [@[message.fromAddress] mutableCopy];
        }
        
        [ccAddressList removeObject:accountAddress];
    }
    
    *to = toAddressList;
    *cc = ccAddressList;
}

- (id)initWithFrame:(NSRect)frame messageThreadViewController:(SMMessageThreadViewController*)messageThreadViewController draftUid:(uint32_t)draftUid plainText:(BOOL)plainText {
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
        
        _messageThreadViewController = messageThreadViewController;
        
        _messageEditorBase = [[SMMessageEditorBase alloc] init];
        _messageEditorController = [[SMMessageEditorController alloc] initWithDraftUID:draftUid];
        
        _editorsUndoList = [NSMutableArray array];
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        
        // Toolbar
        
        _messageEditorToolbarViewController = [[SMMessageEditorToolbarViewController alloc] initWithNibName:@"SMMessageEditorToolbarViewController" bundle:nil];
        _messageEditorToolbarViewController.view.autoresizingMask = NSViewWidthSizable;
        _messageEditorToolbarViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        _messageEditorToolbarViewController.messageEditorViewController = self;
        
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
        
        // register events
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressFieldContentsChanged:) name:@"AddressFieldContentsChanged" object:nil];
        
        [self initView];
    }
    
    return self;
}

- (void)initView {
    if(_foldPanelViewController) {
        [_foldPanelViewController.view removeFromSuperview];
        _foldPanelViewController = nil;
    }
    
    if(_innerView) {
        if(_innerView != self.view) {
            [_innerView removeFromSuperview];
        }
        
        _innerView = nil;
    }
    
    if(_textAndAttachmentsSplitView) {
        [_textAndAttachmentsSplitView removeFromSuperview];
    }
    
    if(self.embedded) {
        _foldPanelViewController = [[SMInlineButtonPanelViewController alloc] initWithNibName:@"SMInlineButtonPanelViewController" bundle:nil];
        [_foldPanelViewController setButtonTarget:self action:@selector(unfoldHiddenText:)];
        _foldPanelViewController.view.autoresizingMask = NSViewWidthSizable;
        _foldPanelViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        
        _innerView = [[SMFlippedView alloc] init];
        _innerView.autoresizingMask = NSViewWidthSizable;
        _innerView.translatesAutoresizingMaskIntoConstraints = YES;
        _innerView.layer.borderWidth = 1;
        _innerView.layer.cornerRadius = 3;
        _innerView.layer.borderColor = [[NSColor lightGrayColor] CGColor];
        
        [self.view addSubview:_innerView];
    }
    else {
        _messageEditorToolbarViewController.makeWindowButton.hidden = YES;
        
        _innerView = self.view;
    }
    
    _innerView.wantsLayer = YES;

    if(!_textAndAttachmentsSplitView) {
        _textAndAttachmentsSplitView = [[NSSplitView alloc] init];
        _textAndAttachmentsSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _textAndAttachmentsSplitView.translatesAutoresizingMaskIntoConstraints = YES;
        _textAndAttachmentsSplitView.vertical = NO;
        _textAndAttachmentsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    }
    
    [_innerView addSubview:_messageEditorToolbarViewController.view];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count > 1) {
        [_innerView addSubview:_fromBoxViewController.view];
    }
    
    [_innerView addSubview:_toBoxViewController.view];
    [_innerView addSubview:_textAndAttachmentsSplitView];
    
    if(_foldPanelViewController != nil) {
        [_innerView addSubview:_foldPanelViewController.view];
    }
    
    if(!self.embedded) {
        [_innerView addSubview:_subjectBoxViewController.view];
    }
    
    if(_editorToolBoxViewController) {
        [_innerView addSubview:_editorToolBoxViewController.view];
    }
 
    if(!_editorStateInitialized) {
        // Controls initialization
        
        if(!self.embedded) {
            [self showFullAddressPanel:YES];
        }
        else {
            [self hideFullAddressPanel:YES];
        }
        
        [_fromBoxViewController.label setStringValue:@"From:"];
        [_toBoxViewController.label setStringValue:@"To:"];
        [_ccBoxViewController.label setStringValue:@"Cc:"];
        [_bccBoxViewController.label setStringValue:@"Bcc:"];
        [_subjectBoxViewController.label setStringValue:@"Subject:"];
        
        [_toBoxViewController addControlSwitch:(self.embedded? NSOffState : NSOnState) target:self action:@selector(toggleFullAddressPanel:)];
        
        // editor initialization

        if(_plainText) {
            [self makePlainText:YES conversion:EditorConversion_Direct];
        }
        else {
            [self makeHTMLText:YES conversion:EditorConversion_Direct];
        }
        
        // other stuff
        
        _attachmentsPanelShown = YES;
        [self hideAttachmentsPanel];

        // Event registration
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenFieldHeightChanged:) name:@"SMTokenFieldHeightChanged" object:nil];
        
        _editorStateInitialized = YES;
    }
    else {
        if(_fullAddressPanelShown) {
            [self addFullAddressPanelSubviews];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)embedded {
    return _messageThreadViewController != nil;
}

- (void)ensureAttachmentsPanelCreated {
    if(_attachmentsPanelViewController != nil) {
        SM_LOG_DEBUG(@"attachments panel already created");
        return;
    }
    
    _attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
    
    [_attachmentsPanelViewController enableEditing:_messageEditorController];
    [_attachmentsPanelViewController setToggleTarget:self action:@selector(toggleAttachmentsPanel:)];
    
    [_textAndAttachmentsSplitView insertArrangedSubview:_attachmentsPanelViewController.view atIndex:1];
}

- (void)viewDidLoad {
    NSAssert(nil, @"should not happen");
}

- (void)setResponders:(BOOL)initialSetup focusKind:(SMEditorFocusKind)focusKind {
    NSWindow *window = [[self view] window];
    if(window == nil) {
        SM_LOG_WARNING(@"no window yet to set responders for");
        return;
    }

    NSView *editorView = _plainText? _plainTextEditor : _htmlTextEditor;
    
    // Workaround: it is nearly impossible to check if the webview has focus. The first responder in that case has
    // a type of "WebHTMLView", which is a private Apple class. When the focus is on address or subject fields,
    // its type is either NSTokenTextView (subclass of NSTextView), or NSWindow.
    BOOL messageEditorFocus = ![window.firstResponder isKindOfClass:[NSWindow class]] && ![window.firstResponder isKindOfClass:[NSTextView class]];
    NSView *initialResponder = nil;
    
    if(!messageEditorFocus || initialSetup) {
        if(focusKind == kEditorFocusKind_Content) {
            initialResponder = editorView;
        }
        else if(focusKind == kEditorFocusKind_ToAddress) {
            initialResponder = _toBoxViewController.tokenField;
        }
        else if(focusKind == kEditorFocusKind_Subject) {
            initialResponder = _subjectBoxViewController.textField;
        }
    }

    if(_fullAddressPanelShown) {
        if(!messageEditorFocus && initialSetup && initialResponder == nil) {
            initialResponder = _subjectBoxViewController.textField;
        }
        
        [window setInitialFirstResponder:_subjectBoxViewController.textField];
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        if(appDelegate.accounts.count > 1) {
            [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
        }
        
        [_toBoxViewController.tokenField setNextKeyView:_ccBoxViewController.tokenField];
        [_ccBoxViewController.tokenField setNextKeyView:_bccBoxViewController.tokenField];
        [_bccBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
        [_subjectBoxViewController.textField setNextKeyView:editorView];
    }
    else {
        if(!self.embedded) {
            if(!messageEditorFocus && initialSetup && initialResponder == nil) {
                initialResponder = _subjectBoxViewController.textField;
            }
            
            [window setInitialFirstResponder:_subjectBoxViewController.textField];
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            if(appDelegate.accounts.count > 1) {
                [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
            }
            
            [_toBoxViewController.tokenField setNextKeyView:_subjectBoxViewController.textField];
            [_subjectBoxViewController.textField setNextKeyView:editorView];
        }
        else {
            if(!messageEditorFocus && initialSetup && initialResponder == nil) {
                initialResponder = _toBoxViewController.tokenField;
            }
            
            [window setInitialFirstResponder:_toBoxViewController.tokenField];
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            if(appDelegate.accounts.count > 1) {
                [_fromBoxViewController.itemList setNextKeyView:_toBoxViewController.tokenField];
            }
            
            [_toBoxViewController.tokenField setNextKeyView:editorView];
        }
    }

    if(initialResponder != nil) {
        [window makeFirstResponder:initialResponder];
    }
}

#pragma mark Editor startup

- (NSString*)fromItemForAccount:(NSUInteger)accountIdx {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    return [NSString stringWithFormat:@"%@ <%@> — %@", [preferencesController fullUserName:accountIdx], [preferencesController userEmail:accountIdx], [preferencesController accountName:accountIdx]];
}

- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray<SMAddress*>*)to cc:(NSArray<SMAddress*>*)cc bcc:(NSArray<SMAddress*>*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments {
    
    // Force the view loading for the 'from' box.
    // Otherwise the following sequence is incorrect.
    [_fromBoxViewController view];
    
    NSAssert(_fromBoxViewController.itemList != nil, @"_fromBoxViewController.itemList == nil");
    [_fromBoxViewController.itemList removeAllItems];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    for(NSUInteger i = 0, n = preferencesController.accountsCount; i < n; i++) {
        NSString *fromItem = [self fromItemForAccount:i];
        
        [_fromBoxViewController.itemList addItemWithTitle:fromItem];
        [_fromBoxViewController.itemList.lastItem setRepresentedObject:appDelegate.accounts[i]];
    }
    
    if(appDelegate.currentAccountIsUnified) {
        // TODO: select the account matching the "to" if it's the reply being composed
        [_fromBoxViewController.itemList selectItemAtIndex:0];
    }
    else {
        [_fromBoxViewController.itemList selectItemWithTitle:[self fromItemForAccount:appDelegate.currentAccountIdx]];
    }
    
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
    
    if(mcoAttachments != nil && mcoAttachments.count > 0) {
        [self ensureAttachmentsPanelCreated];
        
        [_attachmentsPanelViewController setMCOAttachments:mcoAttachments];
        
        [self showAttachmentsPanel];
    }
    
    _lastAccount = _fromBoxViewController.itemList.selectedItem.representedObject;
    _lastSubject = _subjectBoxViewController.textField.stringValue;
    _lastFrom = _fromBoxViewController.itemList.titleOfSelectedItem;
    _lastTo = _toBoxViewController.tokenField.objectValue;
    _lastCc = _ccBoxViewController.tokenField.objectValue;
    _lastBcc = _bccBoxViewController.tokenField.objectValue;
    
    BOOL sendEnabled = (to != nil && to.count != 0);
    [_messageEditorToolbarViewController.sendButton setEnabled:sendEnabled];
    
    [_htmlTextEditor startEditorWithHTML:messageHtmlBody kind:editorKind];
}

#pragma mark Message actions

- (void)sendMessage {
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;

    SMUserAccount *account = _fromBoxViewController.itemList.selectedItem.representedObject;

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(![[appDelegate accounts] containsObject:account]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot send message, as the chosen user account %@ does not exist.", from]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return;
    }
    
    [self removeAllHighlightedOccurrencesOfString];

    NSString *messageText = _plainText? [_plainTextEditor.textView string] : [_htmlTextEditor getMessageText];
    
    if(![_messageEditorController sendMessage:messageText plainText:_plainText subject:_subjectBoxViewController.textField.objectValue from:[[SMAddress alloc] initWithStringRepresentation:from] to:_toBoxViewController.tokenField.objectValue cc:_ccBoxViewController.tokenField.objectValue bcc:_bccBoxViewController.tokenField.objectValue account:account]) {
        SM_LOG_WARNING(@"Cannot send the message from account %@", from);
        return;
    }
    
    if(!self.embedded) {
        [[[self view] window] close];
    }
    else {
        [_messageThreadViewController closeEmbeddedEditorWithoutSavingDraft];
    }
}

- (void)deleteEditedDraft {
    if(self.hasUnsavedContents || _messageEditorController.hasUnsavedAttachments || _messageEditorController.hasSavedDraft) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:@"Are you sure you want to discard this draft?"];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if([alert runModal] != NSAlertFirstButtonReturn) {
            SM_LOG_DEBUG(@"delete cancelled");
            return;
        }
        
        [_messageEditorController deleteSavedDraft:_lastAccount];
    }
    
    _doNotSaveDraftOnClose = YES;
    
    if(self.embedded) {
        [SMNotificationsController localNotifyDeleteEditedMessageDraft:self account:_lastAccount];
    }
    else {
        [[[self view] window] close];
    }
}

- (BOOL)hasUnsavedContents {
    NSString *subject = _subjectBoxViewController.textField.stringValue;
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;
    NSArray *to = _toBoxViewController.tokenField.objectValue;
    NSArray *cc = _ccBoxViewController.tokenField.objectValue;
    NSArray *bcc = _bccBoxViewController.tokenField.objectValue;

    if(_plainText) {
        if(_plainTextEditor.unsavedContentPending) {
            return YES;
        }
    }
    else {
        if(_htmlTextEditor.unsavedContentPending) {
            return YES;
        }
    }

    if(_messageEditorController.hasUnsavedAttachments) {
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

- (BOOL)saveMessage {
    if(![self hasUnsavedContents]) {
        SM_LOG_DEBUG(@"Message contains no changes, so no save is neccessary");
        return TRUE;
    }
    
    if(_fromBoxViewController.itemList.numberOfItems == 0 || _fromBoxViewController.itemList.selectedItem == nil) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot save message, as no user account is chosen for it."]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return FALSE;
    }
    
    NSString *from = _fromBoxViewController.itemList.titleOfSelectedItem;
    SMUserAccount *account = _fromBoxViewController.itemList.selectedItem.representedObject;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(![[appDelegate accounts] containsObject:account]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Cannot save message, as the chosen user account %@ does not exist.", from]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        
        return FALSE;
    }
    
    SM_LOG_INFO(@"Message has changed, a draft will be saved");
    
    if(_findContentsActive && !_plainText) {
        [self removeAllHighlightedOccurrencesOfString];
    }
    
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
    
    NSString *messageText = _plainText? [_plainTextEditor.textView string] : [_htmlTextEditor getMessageText];
    
    [_messageEditorController saveDraft:messageText plainText:_plainText subject:subject from:[[SMAddress alloc] initWithStringRepresentation:from] to:to cc:cc bcc:bcc account:account];

    if(_findContentsActive && !_plainText) {
        [self restoreStringOccurrencesHightlighting];
    }

    if(_plainText) {
        _plainTextEditor.unsavedContentPending = NO;
    }
    else {
        _htmlTextEditor.unsavedContentPending = NO;
    }
    
    _savedOnce = YES;
    
    return TRUE;
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

- (void)createHTMLEditorToolbox {
    _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
    _editorToolBoxViewController.messageEditorViewController = self;
    _editorToolBoxViewController.view.autoresizingMask = NSViewWidthSizable;
    _editorToolBoxViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    [_editorToolBoxViewController.fontSelectionButton removeAllItems];
    [_editorToolBoxViewController.fontSelectionButton addItemsWithTitles:[SMMessageEditorBase fontFamilies]];
    [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:0];
    
    NSArray *textSizes = [[NSArray alloc] initWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    
    [_editorToolBoxViewController.textSizeButton removeAllItems];
    [_editorToolBoxViewController.textSizeButton addItemsWithTitles:textSizes];
    [_editorToolBoxViewController.textSizeButton selectItemAtIndex:2];
    
    _editorToolBoxViewController.textForegroundColorSelector.icon = [NSImage imageNamed:@"text-color.png"];
    _editorToolBoxViewController.textBackgroundColorSelector.icon = [NSImage imageNamed:@"background-color.png"];
}

#pragma mark Text attrbitute actions

- (void)makeHTMLText {
    [self makeHTMLText:NO conversion:EditorConversion_Direct];
}

- (void)makeHTMLText:(BOOL)force conversion:(EditorConversion)conversion {
    if(!_plainText && !force) {
        return;
    }
    
    _plainText = NO;

    [self removeAllHighlightedOccurrencesOfString];
    [self hideFindContentsPanel];

    [self createHTMLEditorToolbox];
    
    [_innerView addSubview:_editorToolBoxViewController.view];

    CGFloat dividerPos = 0;
    BOOL restoreDividerPos = NO;
    if(_textAndAttachmentsSplitView.subviews.count == 2) {
        dividerPos = _textAndAttachmentsSplitView.subviews[0].frame.size.height;
        restoreDividerPos = YES;
    }

    if(_textAndAttachmentsSplitView.subviews.count > 0) {
        [_textAndAttachmentsSplitView.subviews[0] removeFromSuperview];
    }

    if(conversion != EditorConversion_Direct) {
        if(conversion == EditorConversion_Undo) {
            if(_editorUndoLevel == _editorsUndoList.count) {
                [_editorsUndoList addObject:_plainTextEditor];
            }
            else {
                NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo list corrupted");
                _editorsUndoList[_editorUndoLevel] = _plainTextEditor;
            }

            NSAssert(_editorUndoLevel > 0, @"editor undo level is zero");
            _editorUndoLevel--;
        }
        else {
            NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo level is too high");
            _editorUndoLevel++;
        }
        
        NSAssert(_editorsUndoList.count > 0, @"editor undo list empty");
        NSAssert([_editorsUndoList[_editorUndoLevel] isKindOfClass:[SMHTMLMessageEditorView class]], @"bad object in the editor undo list");
        NSAssert(_htmlTextEditor == nil, @"_htmlTextEditor is nil");
        
        _htmlTextEditor = (SMHTMLMessageEditorView*)_editorsUndoList[_editorUndoLevel];
        
        NSAssert(_plainTextEditor != nil, @"_plainTextEditor is already nil");
        _plainTextEditor = nil;
    }
    else {
        _htmlTextEditor = [[SMHTMLMessageEditorView alloc] init];
        _htmlTextEditor.translatesAutoresizingMaskIntoConstraints = YES;
        _htmlTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        if(_plainTextEditor) {
            if(_editorUndoLevel == _editorsUndoList.count) {
                [_editorsUndoList addObject:_plainTextEditor];
            }
            else {
                NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo list corrupted");
                _editorsUndoList[_editorUndoLevel] = _plainTextEditor;
            }
            
            _editorUndoLevel++;

            // TODO: get rid of <pre> and do it right, see issue #90
            NSString *htmlText = [NSString stringWithFormat:@"<pre>%@</pre>", _plainTextEditor.textView.string];
            [_htmlTextEditor startEditorWithHTML:htmlText kind:kUnfoldedDraftEditorContentsKind];

            _plainTextEditor = nil;
        }
    }
    
    _htmlTextEditor.messageEditorBase = _messageEditorBase;
    _htmlTextEditor.editorToolBoxViewController = _editorToolBoxViewController;
    
    [_textAndAttachmentsSplitView insertArrangedSubview:_htmlTextEditor atIndex:0];
    [_textAndAttachmentsSplitView adjustSubviews];

    if(restoreDividerPos) {
        [_textAndAttachmentsSplitView setPosition:dividerPos ofDividerAtIndex:0];
    }
    
    [self adjustFrames:FrameAdjustment_Resize];
    [self setResponders:NO focusKind:kEditorFocusKind_Invalid];
    
    // Setup undo
    
    [_htmlTextEditor.undoManager registerUndoWithTarget:self selector:@selector(undoMakeHTMLText:) object:_htmlTextEditor];
    [_htmlTextEditor.undoManager setActionName:NSLocalizedString(@"Convert to HTML", @"convert to html")];
    
    // Adjust the main menu
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    appController.htmlTextFormatMenuItem.state = NSOnState;
    appController.plainTextFormatMenuItem.state = NSOffState;
}

- (void)undoMakeHTMLText:(id)object {
    EditorConversion conversion = [[((SMHTMLMessageEditorView*)object) undoManager] isUndoing]? EditorConversion_Undo : EditorConversion_Redo;
    
    [self makePlainText:NO conversion:conversion];
}

- (void)makePlainText {
    [self makePlainText:NO conversion:EditorConversion_Direct];
}

- (void)makePlainText:(BOOL)force conversion:(EditorConversion)conversion {
    if(_plainText && !force) {
        return;
    }
    
    _plainText = YES;
    
    [self removeAllHighlightedOccurrencesOfString];
    [self hideFindContentsPanel];
    
    [_editorToolBoxViewController.view removeFromSuperview];
    
    _editorToolBoxViewController = nil;
    _htmlTextEditor.editorToolBoxViewController = nil;
 
    CGFloat dividerPos = 0;
    BOOL restoreDividerPos = NO;
    if(_textAndAttachmentsSplitView.subviews.count == 2) {
        dividerPos = _textAndAttachmentsSplitView.subviews[0].frame.size.height;
        restoreDividerPos = YES;
    }
    
    if(_textAndAttachmentsSplitView.subviews.count > 0) {
        [_textAndAttachmentsSplitView.subviews[0] removeFromSuperview];
    }

    if(conversion != EditorConversion_Direct) {
        if(conversion == EditorConversion_Undo) {
            if(_editorUndoLevel == _editorsUndoList.count) {
                [_editorsUndoList addObject:_htmlTextEditor];
            }
            else {
                NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo list corrupted");
                _editorsUndoList[_editorUndoLevel] = _htmlTextEditor;
            }

            NSAssert(_editorUndoLevel > 0, @"editor undo level is zero");
            _editorUndoLevel--;
        }
        else {
            NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo level is too high");
            _editorUndoLevel++;
        }
        
        NSAssert(_editorsUndoList.count > 0, @"editor undo list empty");
        NSAssert([_editorsUndoList[_editorUndoLevel] isKindOfClass:[SMPlainTextMessageEditor class]], @"bad object in the editor undo list");
        NSAssert(_plainTextEditor == nil, @"_plainTextEditor is nil");
        
        _plainTextEditor = (SMPlainTextMessageEditor*)_editorsUndoList[_editorUndoLevel];
        
        NSAssert(_htmlTextEditor != nil, @"_htmlTextEditor is already nil");
        _htmlTextEditor = nil;
    }
    else {
        NSString *plainText = nil;
        
        if(_htmlTextEditor) {
            if(_htmlTextEditor.mainFrame != nil) {
                plainText = [(DOMHTMLElement *)[[_htmlTextEditor.mainFrame DOMDocument] documentElement] outerText];
            }
            
            if(_editorUndoLevel == _editorsUndoList.count) {
                [_editorsUndoList addObject:_htmlTextEditor];
            }
            else {
                NSAssert(_editorUndoLevel < _editorsUndoList.count, @"editor undo list corrupted");
                _editorsUndoList[_editorUndoLevel] = _htmlTextEditor;
            }

            _editorUndoLevel++;
            
            _htmlTextEditor = nil;
        }
        else {
            NSString *signature;
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            if([[appDelegate preferencesController] shouldUseSingleSignature]) {
                signature = [[appDelegate preferencesController] singleSignature];
            }
            else if(appDelegate.currentAccountIsUnified) {
                signature = [[appDelegate preferencesController] accountSignature:0];
            }
            else {
                signature = [[appDelegate preferencesController] accountSignature:appDelegate.currentAccountIdx];
            }
            
            // convert html signature to plain text
            NSAttributedString *signatureHtmlAttributedString = [[NSAttributedString alloc] initWithData:[signature dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute:@(NSUTF8StringEncoding)} documentAttributes:nil error:nil];
            
            plainText = [NSString stringWithFormat:@"\n\n%@", [SMStringUtils trimString:signatureHtmlAttributedString.string]];
        }
        
        _plainTextEditor = [[SMPlainTextMessageEditor alloc] initWithString:plainText];
        _plainTextEditor.translatesAutoresizingMaskIntoConstraints = YES;
        _plainTextEditor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    
    [_textAndAttachmentsSplitView insertArrangedSubview:_plainTextEditor atIndex:0];
    [_textAndAttachmentsSplitView adjustSubviews];
    
    if(restoreDividerPos) {
        [_textAndAttachmentsSplitView setPosition:dividerPos ofDividerAtIndex:0];
    }

    [self adjustFrames:FrameAdjustment_Resize];
    [self setResponders:NO focusKind:kEditorFocusKind_Invalid];
    
    // Setup undo
    
    [_plainTextEditor.undoManager registerUndoWithTarget:self selector:@selector(undoMakePlainText:) object:_plainTextEditor];
    [_plainTextEditor.undoManager setActionName:NSLocalizedString(@"Convert to Plain Text", @"convert to plain text")];
    
    // Adjust the main menu
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    appController.htmlTextFormatMenuItem.state = NSOffState;
    appController.plainTextFormatMenuItem.state = NSOnState;
}

- (void)undoMakePlainText:(id)object {
    EditorConversion conversion = [[((SMPlainTextMessageEditor*)object) undoManager] isUndoing]? EditorConversion_Undo : EditorConversion_Redo;
    
    [self makeHTMLText:NO conversion:conversion];
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
    
    [self setResponders:NO focusKind:kEditorFocusKind_Invalid];
}

- (void)addFullAddressPanelSubviews {
    [_innerView addSubview:_ccBoxViewController.view];
    [_innerView addSubview:_bccBoxViewController.view];
    
    if(self.embedded) {
        [_innerView addSubview:_subjectBoxViewController.view];
    }
}
    
- (void)showFullAddressPanel:(BOOL)viewConstructionPhase {
    _fullAddressPanelShown = YES;
    
    [self addFullAddressPanelSubviews];
    [self adjustFrames:(viewConstructionPhase? FrameAdjustment_Resize : FrameAdjustment_ShowFullPanel)];
    [self notifyContentHeightChanged];
}

- (void)hideFullAddressPanel:(BOOL)viewConstructionPhase {
    _fullAddressPanelShown = NO;
    
    [_ccBoxViewController.view removeFromSuperview];
    [_bccBoxViewController.view removeFromSuperview];
    
    if(self.embedded) {
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
    
    if(self.embedded) {
        _innerView.frame = NSMakeRect(EMBEDDED_MARGIN_W, EMBEDDED_MARGIN_H, self.view.frame.size.width - EMBEDDED_MARGIN_W * 2 - 2, self.view.frame.size.height - EMBEDDED_MARGIN_H * 2);
    }
    
    const CGFloat curWidth = _innerView.frame.size.width;
    const CGFloat curHeight = _innerView.frame.size.height;
    
    CGFloat yPos = 0;
    
    _messageEditorToolbarViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _messageEditorToolbarViewController.view.frame.size.height);
    
    yPos += _messageEditorToolbarViewController.view.frame.size.height;
    
    BOOL fromShown = NO;
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count > 1) {
        _fromBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _fromBoxViewController.view.frame.size.height);
        
        yPos += _fromBoxViewController.view.frame.size.height;
        
        fromShown = YES;
    }
    
    CGFloat gridOffset = 22;
    NSColor *gridColor = [NSColor colorWithWhite:0.86 alpha:1];
    
    SMLabeledTokenFieldBoxView *prevFieldView;
    
    _toBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _toBoxViewController.contentViewHeight);
    _toBoxViewController.mainView.drawTopLine = (fromShown? YES : NO);
    _toBoxViewController.mainView.drawBottomLine = YES;
    _toBoxViewController.mainView.topLineOffset = gridOffset;
    _toBoxViewController.mainView.bottomLineOffset = gridOffset;
    _toBoxViewController.mainView.lineColor = gridColor;
    _toBoxViewController.mainView.needsDisplay = YES;

    prevFieldView = _toBoxViewController.mainView;

    yPos += _toBoxViewController.contentViewHeight;
    
    CGFloat fullAddressPanelHeight = 0;
    
    if(_fullAddressPanelShown) {
        prevFieldView.drawBottomLine = NO;
        prevFieldView = _ccBoxViewController.mainView;
        
        _ccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _ccBoxViewController.contentViewHeight);
        _ccBoxViewController.mainView.drawTopLine = YES;
        _ccBoxViewController.mainView.drawBottomLine = YES;
        _ccBoxViewController.mainView.topLineOffset = gridOffset;
        _ccBoxViewController.mainView.bottomLineOffset = gridOffset;
        _ccBoxViewController.mainView.lineColor = gridColor;
        _ccBoxViewController.mainView.needsDisplay = YES;
        
        yPos += _ccBoxViewController.view.frame.size.height;
        
        prevFieldView.drawBottomLine = NO;
        prevFieldView = _bccBoxViewController.mainView;

        _bccBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _bccBoxViewController.contentViewHeight);
        _bccBoxViewController.mainView.drawTopLine = YES;
        _bccBoxViewController.mainView.drawBottomLine = YES;
        _bccBoxViewController.mainView.topLineOffset = gridOffset;
        _bccBoxViewController.mainView.bottomLineOffset = gridOffset;
        _bccBoxViewController.mainView.lineColor = gridColor;
        _bccBoxViewController.mainView.needsDisplay = YES;
        
        yPos += _bccBoxViewController.view.frame.size.height;
        
        fullAddressPanelHeight += _ccBoxViewController.view.frame.size.height + _bccBoxViewController.view.frame.size.height;
    }

    prevFieldView.drawBottomLine = NO;

    if(!self.embedded || _fullAddressPanelShown) {
        prevFieldView = _subjectBoxViewController.mainView;

        _subjectBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _subjectBoxViewController.view.frame.size.height);
        _subjectBoxViewController.mainView.drawTopLine = YES;
        _subjectBoxViewController.mainView.drawBottomLine = NO;
        _subjectBoxViewController.mainView.topLineOffset = gridOffset;
        _subjectBoxViewController.mainView.bottomLineOffset = gridOffset;
        _subjectBoxViewController.mainView.lineColor = gridColor;
        _subjectBoxViewController.mainView.needsDisplay = YES;
        
        yPos += _subjectBoxViewController.view.frame.size.height;

        fullAddressPanelHeight += _subjectBoxViewController.view.frame.size.height;
    }
    
    if(!_plainText) {
        _editorToolBoxViewController.view.frame = NSMakeRect(-1, yPos, curWidth+2, _editorToolBoxViewController.view.frame.size.height);
        
        yPos += _editorToolBoxViewController.view.frame.size.height;
    }
    else {
        prevFieldView.bottomLineOffset = 0;
        prevFieldView.drawBottomLine = YES;
    }
    
    _panelHeight = yPos - 1;
    
    const CGFloat foldButtonHeight = (_foldPanelViewController != nil? _foldPanelViewController.view.frame.size.height : 0);
    
    CGFloat fullPanelHeightAdjustment = 0;
    if(self.embedded) {
        if(frameAdjustment == FrameAdjustment_ShowFullPanel) {
            fullPanelHeightAdjustment = fullAddressPanelHeight;
        }
        else if(frameAdjustment == FrameAdjustment_HideFullPanel) {
            fullPanelHeightAdjustment = -fullAddressPanelHeight;
        }
        
        [_innerView setFrameSize:NSMakeSize(_innerView.frame.size.width, _innerView.frame.size.height + fullPanelHeightAdjustment)];
    }
    
    if(_findContentsPanelShown) {
        _findContentsPanelViewController.view.frame = NSMakeRect(0, yPos, curWidth, _findContentsPanelViewController.view.frame.size.height);
        
        yPos += _findContentsPanelViewController.view.frame.size.height;
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
        
        [_messageEditorToolbarViewController.sendButton setEnabled:(toValue.length != 0)];
    }
}

#pragma mark Attachments panel

- (void)toggleAttachmentsPanel:(id)sender {
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

- (BOOL)closeEditor:(BOOL)shouldSaveDraft askConfirmationIfNecessary:(BOOL)askConfirmationIfNecessary {
    if(shouldSaveDraft && !_doNotSaveDraftOnClose) {
        BOOL doSave = YES;
        
        if(askConfirmationIfNecessary) {
            if(!_savedOnce && [self hasUnsavedContents]) {
                NSAlert *alert = [[NSAlert alloc] init];
                
                [alert addButtonWithTitle:@"Save"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert addButtonWithTitle:@"Don't save"];
                [alert setMessageText:[NSString stringWithFormat:@"Would you like to save this draft?"]];
                [alert setInformativeText:[NSString stringWithFormat:@"This message contains unsaved changes. You can save it as a draft to finish working on later."]];
                [alert setAlertStyle:NSAlertStyleInformational];
                
                NSModalResponse response = [alert runModal];
                
                if(response == NSAlertSecondButtonReturn) {
                    return FALSE;
                }
                else if(response == NSAlertThirdButtonReturn) {
                    doSave = NO;
                }
            }
        }
        
        if(doSave) {
            if(![self saveMessage]) {
                return FALSE;
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_htmlTextEditor stopTextMonitor];
    
    return TRUE;
}

- (void)saveDocument:(id)sender {
    [self saveMessage];
}

#pragma mark Find Contents panel

- (void)showFindContentsPanel:(BOOL)replace {
    if(_findContentsPanelViewController == nil) {
        _findContentsPanelViewController = [[SMEditorFindContentsPanelViewController alloc] initWithNibName:@"SMEditorFindContentsPanelViewController" bundle:nil];
        _findContentsPanelViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        _findContentsPanelViewController.view.autoresizingMask = NSViewWidthSizable;
        _findContentsPanelViewController.messageEditorViewController = self;
    }
    
    if(replace) {
        [_findContentsPanelViewController showReplaceControls];
    }
    else {
        [_findContentsPanelViewController hideReplaceControls];
    }
    
    if(!_findContentsPanelShown) {
        [self.view addSubview:_findContentsPanelViewController.view];
        
        _findContentsPanelShown = YES;
    }
    
    NSSearchField *findField = _findContentsPanelViewController.findField;
    NSAssert(findField != nil, @"findField == nil");

    [[findField window] makeFirstResponder:findField];
    
    [self adjustFrames:FrameAdjustment_Resize];
}

- (void)hideFindContentsPanel {
    if(!_findContentsPanelShown)
        return;
    
    [_findContentsPanelViewController.view removeFromSuperview];
    
    _findContentsPanelShown = NO;
    
    [self adjustFrames:FrameAdjustment_Resize];
}

#pragma mark Finding messages contents

- (void)findContents:(NSString*)stringToFind matchCase:(BOOL)matchCase forward:(BOOL)forward {
    if((_currentStringToFind != nil && ![_currentStringToFind isEqualToString:stringToFind]) || !_stringOccurrenceMarked) {
        if(_stringOccurrenceMarked) {
            [self removeMarkedOccurrenceOfFoundString];

            _stringOccurrenceMarkedResultIndex = 0;
            _stringOccurrenceMarked = NO;
        }
        
        [self highlightAllOccurrencesOfString:stringToFind matchCase:matchCase];
        
        if(!_stringOccurrenceMarked) {
            if([self stringOccurrencesCount] > 0) {
                _stringOccurrenceMarked = YES;
                
                [self markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
            }
        }
        
        _currentStringToFind = stringToFind;
        _currentStringToFindMatchCase = matchCase;
    } else {
        NSUInteger occurrencesCount = [self stringOccurrencesCount];

        if(occurrencesCount > 0) {
            // this is the case when there is a marked occurrence already
            // so we just need to move it forward or backwards
            // just scan the cells in the corresponsing direction and choose the right place
            
            NSAssert(_stringOccurrenceMarked, @"string occurrence not marked");
            
            if(forward) {
                if(_stringOccurrenceMarkedResultIndex+1 < occurrencesCount) {
                    _stringOccurrenceMarkedResultIndex++;
                }
                else {
                    _stringOccurrenceMarkedResultIndex = 0;
                }
            }
            else {
                if(_stringOccurrenceMarkedResultIndex > 0) {
                    _stringOccurrenceMarkedResultIndex--;
                }
                else {
                    _stringOccurrenceMarkedResultIndex = occurrencesCount-1;
                }
            }
            
            [self markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
        }
    }
    
    // if there is a marked occurrence, make sure it is visible
    // just scroll the editor view to the right position
    if(_stringOccurrenceMarked) {
        [self animatedScrollToMarkedOccurrence];
    }
    
    _findContentsActive = YES;
}

- (void)animatedScrollToMarkedOccurrence {
    if(_plainText) {
        [_plainTextEditor animatedScrollToMarkedOccurrence];
    }
    else {
        [_htmlTextEditor animatedScrollToMarkedOccurrence];
    }
}

- (void)removeFindContentsResults {
    [self removeAllHighlightedOccurrencesOfString];
    
    [self clearStringOccurrenceMarkIndex];
    
    _currentStringToFind = nil;
    _currentStringToFindMatchCase = NO;
    _findContentsActive = NO;
}

- (void)clearStringOccurrenceMarkIndex {
    _stringOccurrenceMarked = NO;
}

- (NSInteger)stringOccurrencesCount {
    if(_plainText) {
        return [_plainTextEditor stringOccurrencesCount];
    }
    else {
        return [_htmlTextEditor stringOccurrencesCount];
    }
}

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    if(_plainText) {
        [_plainTextEditor highlightAllOccurrencesOfString:str matchCase:matchCase];
    }
    else {
        [_htmlTextEditor highlightAllOccurrencesOfString:str matchCase:matchCase];
    }
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
    if(_plainText) {
        [_plainTextEditor markOccurrenceOfFoundString:index];
    }
    else {
        [_htmlTextEditor markOccurrenceOfFoundString:index];
    }
}

- (void)removeMarkedOccurrenceOfFoundString {
    if(_plainText) {
        [_plainTextEditor removeMarkedOccurrenceOfFoundString];
    }
    else {
        [_htmlTextEditor removeMarkedOccurrenceOfFoundString];
    }
}

- (void)removeAllHighlightedOccurrencesOfString {
    if(_plainText) {
        [_plainTextEditor removeAllHighlightedOccurrencesOfString];
    }
    else {
        [_htmlTextEditor removeAllHighlightedOccurrencesOfString];
    }
}

- (void)restoreStringOccurrencesHightlighting {
    if(_plainText) {
        // nothing to be done
    }
    else {
        // might not be efficient; a better approach would be to keep
        // the current find state in javascript and just restore it when saving is done
        [self highlightAllOccurrencesOfString:_currentStringToFind matchCase:_currentStringToFindMatchCase];
        [self markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
    }
}

#pragma mark Replacing contents

- (void)replaceOccurrence:(NSString*)replacement {
    if(_plainText) {
        [_plainTextEditor replaceOccurrence:_stringOccurrenceMarkedResultIndex replacement:replacement];
    }
    else {
        [_htmlTextEditor replaceOccurrence:_stringOccurrenceMarkedResultIndex replacement:replacement];        
    }

    if(_stringOccurrenceMarkedResultIndex == self.stringOccurrencesCount) {
        _stringOccurrenceMarkedResultIndex = 0;
    }

    [self markOccurrenceOfFoundString:_stringOccurrenceMarkedResultIndex];
    [self animatedScrollToMarkedOccurrence];
}

- (void)replaceAllOccurrences:(NSString*)replacement {
    if(_plainText) {
        [_plainTextEditor replaceAllOccurrences:replacement];
    }
    else {
        [_htmlTextEditor replaceAllOccurrences:replacement];
    }

    _stringOccurrenceMarkedResultIndex = 0;
}

#pragma mark Windowise

- (void)makeWindow {
    [_messageThreadViewController makeEditorWindow:self];
    
    _messageThreadViewController = nil;
    
    [self initView];

    [_htmlTextEditor unfoldContent];

    [self adjustFrames:FrameAdjustment_Resize];
    [self setResponders:NO focusKind:kEditorFocusKind_Invalid];
}

@end
