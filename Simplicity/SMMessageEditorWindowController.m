//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <WebKit/WebUIDelegate.h>

#import <MailCore/MailCore.h>

#import "SMTokenField.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    SMMessageEditorController *_messageEditorController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSMutableArray *_attachmentsPanelViewConstraints;
    Boolean _attachmentsPanelShown;
}

- (void)awakeFromNib {
	NSLog(@"%s", __func__);
    
    // Controller
    
    _messageEditorController = [[SMMessageEditorController alloc] init];

	// To
	
	_toBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];

	[_toBoxView addSubview:_toBoxViewController.view];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

	[_toBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_toBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

	// Cc

	_ccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
	
	[_ccBoxView addSubview:_ccBoxViewController.view];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
	
	[_ccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_ccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
	
	// Bcc
	
	_bccBoxViewController = [[SMLabeledTokenFieldBoxViewController alloc] initWithNibName:@"SMLabeledTokenFieldBoxViewController" bundle:nil];
	
	[_bccBoxView addSubview:_bccBoxViewController.view];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
	
	[_bccBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_bccBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bccBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
	
	// register events
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	[_toBoxViewController.label setStringValue:@"To:"];
	[_ccBoxViewController.label setStringValue:@"Cc:"];
	[_bccBoxViewController.label setStringValue:@"Bcc:"];
	
	[_messageTextEditor setFrameLoadDelegate:self];
	[_messageTextEditor setPolicyDelegate:self];
	[_messageTextEditor setResourceLoadDelegate:self];
    [_messageTextEditor setEditingDelegate:self];
	[_messageTextEditor setCanDrawConcurrently:YES];
	[_messageTextEditor setEditable:YES];
	
	[_sendButton setEnabled:NO];

    NSArray *textSizes = [[NSArray alloc] initWithObjects:@"8", @"9", @"10", @"11", @"12", @"13", @"14", @"18", @"24", @"36", @"48", @"64", @"72", @"96", @"144", @"288", nil];

    [_textSizeButton removeAllItems];
    [_textSizeButton addItemsWithTitles:textSizes];
    [_textSizeButton selectItemAtIndex:2];
    
    NSArray *justifyOptions = [[NSArray alloc] initWithObjects:@"Left", @"Center", @"Right", nil];
    
    [_justifyButton removeAllItems];
    [_justifyButton addItemsWithTitles:justifyOptions];
    [_justifyButton selectItemAtIndex:0];

    [self startEditor];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame == [frame findFrameNamed:@"_top"]) {
        //
        // Bridge between JavaScript's console.log and Cocoa NSLog
        // http://jerodsanto.net/2010/12/bridging-the-gap-between-javascripts-console-log-and-cocoas-nslog/
        //
        WebScriptObject *scriptObject = [sender windowScriptObject];
        [scriptObject setValue:self forKey:@"Simplicity"];
        [scriptObject evaluateWebScript:@"console = { log: function(msg) { Simplicity.consoleLog_(msg); } }"];
    }

    if(sender != nil && frame == sender.mainFrame) {
        NSArray *scripts = [NSArray arrayWithObjects:@"wysihtml5x-rules", @"wysihtml5x-toolbar", @"editor_api", nil];
        
        for(NSString *s in scripts) {
            NSString *path = [[NSBundle mainBundle] pathForResource:s ofType:@"js"];
            NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            
            NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:jsCode];
            NSLog(@"%s: script '%@' loading result '%@'", __func__, s, ret);
        }
        
        NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorStart()"];
        NSLog(@"%s: editor start result '%@'", __func__, ret);
        
        NSAssert([ret isEqualToString:@"Success"], @"Failed to init editor, error '%@'", ret);
    }
}

- (void)consoleLog:(NSString *)message {
    NSLog(@"JSLog: %@", message);
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
    if (aSelector == @selector(consoleLog:)) {
        return NO;
    }
    
    return YES;
}

#pragma mark Editor

- (void)startEditor {
    NSString *htmlText = @"<div id=\"editor-container\"></div>";
    
    [[_messageTextEditor mainFrame] loadHTMLString:htmlText baseURL:nil];
}

#pragma mark Actions

- (IBAction)sendAction:(id)sender {
    NSString *messageText = [(DOMHTMLElement *)[[[_messageTextEditor mainFrame] DOMDocument] documentElement] outerHTML];

    [_messageEditorController sendMessage:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];

	[self close];
}

- (IBAction)saveAction:(id)sender {
    NSString *messageText = [(DOMHTMLElement *)[[[_messageTextEditor mainFrame] DOMDocument] documentElement] outerHTML];
    
    [_messageEditorController saveDraft:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];
}

- (IBAction)attachAction:(id)sender {
	NSLog(@"%s", __func__);
    [self toggleAttachmentsPanel];
}

#pragma mark Text attrbitute actions

- (IBAction)toggleBoldAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleBold()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)toggleItalicAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleItalic()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)toggleUnderlineAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleUnderline()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)toggleBulletsAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleBullets()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)toggleNumberingAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleNumbering()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)toggleQuoteAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorToggleQuote()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)shiftLeftAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorShiftLeft()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)shiftRightAction:(id)sender {
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"Simplicity_EditorShiftRight()"];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)setTextSizeAction:(id)sender {
    NSInteger index = [_textSizeButton indexOfSelectedItem];
    if(index < 0 || index >= _textSizeButton.numberOfItems) {
        NSLog(@"%s: selected text size value index %ld is out of range", __func__, index);
        return;
    }

    NSInteger textSize = [[_textSizeButton itemTitleAtIndex:index] integerValue];
    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"Simplicity_EditorSetTextSize(%ld)", textSize]];
    NSLog(@"%s: ret '%@'", __func__, ret);
}

- (IBAction)justifyTextAction:(id)sender {
    NSInteger index = [_justifyButton indexOfSelectedItem];
    if(index < 0 || index >= _justifyButton.numberOfItems) {
        NSLog(@"%s: selected text size value index %ld is out of range", __func__, index);
        return;
    }

    NSString *justifyFunc = nil;
    
    switch(index) {
        case 0: justifyFunc = @"Simplicity_EditorJustifyLeft()"; break;
        case 1: justifyFunc = @"Simplicity_EditorJustifyCenter()"; break;
        case 2: justifyFunc = @"Simplicity_EditorJustifyRight()"; break;
        default: NSAssert(nil, @"Unexpected index %ld", index);
    }

    NSString *ret = [_messageTextEditor stringByEvaluatingJavaScriptFromString:justifyFunc];
    NSLog(@"%s: func '%@', ret '%@'", __func__, justifyFunc, ret);
}

- (IBAction)showSourceAction:(id)sender {
    NSString *messageText = [(DOMHTMLElement *)[[[_messageTextEditor mainFrame] DOMDocument] documentElement] outerHTML];

    NSLog(@"%@", messageText);
}

#pragma mark UI elements collaboration

- (void)processAddressFieldEditingEnd:(NSNotification*)notification {
	id object = [notification object];
	
	if(object == _toBoxViewController) {
		NSString *toValue = [[_toBoxViewController.tokenField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
		
		// TODO: verify the destination email address / recepient name more carefully

		[_sendButton setEnabled:(toValue.length != 0)];
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
    
    NSView *view = [[self window] contentView];
    NSAssert(view != nil, @"view is nil");
    
    NSAssert(_messageEditorBottomConstraint != nil, @"_messageEditorBottomConstraint not created");
    [view removeConstraint:_messageEditorBottomConstraint];
    
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
    
    NSView *view = [[self window] contentView];
    NSAssert(view != nil, @"view is nil");
    
    NSAssert(_attachmentsPanelViewConstraints != nil, @"_attachmentsPanelViewConstraints not created");
    [view removeConstraints:_attachmentsPanelViewConstraints];
    
    [_attachmentsPanelViewController.view removeFromSuperview];
    
    NSAssert(_messageEditorBottomConstraint != nil, @"_messageEditorBottomConstraint not created");
    [view addConstraint:_messageEditorBottomConstraint];
    
    _attachmentsPanelShown = NO;
}

#pragma mark Drag and drop to HTML editor

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    NSLog(@"%s: TODO", __func__);
    return WebDragDestinationActionEdit;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point {
    //NSLog(@"%s: TODO", __func__);
    return WebDragDestinationActionNone;
}

- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    NSLog(@"%s: TODO", __func__);
/*
    if ( [draggingInfo draggingSource] == nil )
    {
        NSPasteboard *pboard = [draggingInfo draggingPasteboard];
        NSArray *classes = @[ [NSURL class] ];
        NSDictionary *options = @{ NSPasteboardURLReadingFileURLsOnlyKey: [NSNumber numberWithBool:YES],
                                   NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes] };
        NSArray *fileURLs = [pboard readObjectsForClasses:classes options:options];
        
        if(fileURLs)
        {
            NSArray* filenames = [pboard propertyListForType: NSFilenamesPboardType];
            NSMutableString* html = [NSMutableString string];
            
            for(NSString* filename in filenames) {
                [html appendFormat: @"<img src=\"%@\"/>", [[[NSURL alloc] initFileURLWithPath: filename] absoluteString]];
            }
            
            [pboard declareTypes: [NSArray arrayWithObject: NSHTMLPboardType] owner: self];
            [pboard setString: html forType: NSHTMLPboardType];
            
            NSLog(@"html: %@", html);
        }
    }
*/
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard {
    NSLog(@"%s: TODO", __func__);
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action {

    NSLog(@"%s: node '%@', range '%@'", __func__, node, range);
    return YES;
}


@end
