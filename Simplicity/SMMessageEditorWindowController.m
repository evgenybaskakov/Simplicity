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
#import "SMColorWellWithIcon.h"
#import "SMEditorToolBoxViewController.h"
#import "SMLabeledTokenFieldBoxViewController.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageEditorController.h"
#import "SMMessageEditorWindowController.h"

static NSArray *fontFamilies;
static NSArray *fontNames;
static NSDictionary *fontNameToIndexMap;

@implementation SMMessageEditorWindowController {
    NSTimer *_textMonitorTimer;
    SMMessageEditorController *_messageEditorController;
    SMEditorToolBoxViewController *_editorToolBoxViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSMutableArray *_attachmentsPanelViewConstraints;
    Boolean _attachmentsPanelShown;
}

- (void)awakeFromNib {
	NSLog(@"%s", __func__);
    
    // Static data
    
    if(fontNameToIndexMap == nil) {
        fontFamilies = [NSArray arrayWithObjects:
                        @"Sans Serif",
                        @"Serif",
                        @"Fixed Width",
                        @"Wide",
                        @"Narrow",
                        @"Comic Sans MS",
                        @"Garamond",
                        @"Georgia",
                        @"Tahoma",
                        @"Trebuchet MS",
                        @"Verdana",
                        nil];
        
        fontNames = [NSArray arrayWithObjects:
                         @"Arial",
                         @"Times New Roman",
                         @"Courier New",
                         @"Arial Black",
                         @"Arial Narrow",
                         @"Comic Sans MS",
                         @"Times",
                         @"Georgia",
                         @"Tahoma",
                         @"Trebuchet MS",
                         @"Verdana",
                         nil];
        
        NSMutableDictionary *mapping = [NSMutableDictionary dictionary];

        for(NSUInteger i = 0; i < fontNames.count; i++) {
            NSNumber *indexNum = [NSNumber numberWithUnsignedInteger:i];

            [mapping setObject:indexNum forKey:fontNames[i]];
            [mapping setObject:indexNum forKey:[NSString stringWithFormat:@"'%@'", fontNames[i]]];
            [mapping setObject:indexNum forKey:[NSString stringWithFormat:@"\"%@\"", fontNames[i]]];
        }
        
        fontNameToIndexMap = mapping;
    }

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
    
    // editor toolbox
    
    _editorToolBoxViewController = [[SMEditorToolBoxViewController alloc] initWithNibName:@"SMEditorToolBoxViewController" bundle:nil];
    _editorToolBoxViewController.messageEditorWindowController = self;
    
    [_editorToolBoxView addSubview:_editorToolBoxViewController.view];

    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    
    [_editorToolBoxView addConstraint:[NSLayoutConstraint constraintWithItem:_editorToolBoxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_editorToolBoxViewController.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

	// register events
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAddressFieldEditingEnd:) name:@"LabeledTokenFieldEndedEditing" object:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Delegate setup

    [[self window] setDelegate:self];
	
    // Controls initialization

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
    
    // Editor toolbox
    NSAssert(_editorToolBoxViewController != nil, @"editor toolbox is nil");

    [_editorToolBoxViewController.fontSelectionButton removeAllItems];
    [_editorToolBoxViewController.fontSelectionButton addItemsWithTitles:fontFamilies];
    [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:0];
    
    NSArray *textSizes = [[NSArray alloc] initWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    
    [_editorToolBoxViewController.textSizeButton removeAllItems];
    [_editorToolBoxViewController.textSizeButton addItemsWithTitles:textSizes];
    [_editorToolBoxViewController.textSizeButton selectItemAtIndex:2];
    
    _editorToolBoxViewController.textForegroundColorSelector.icon = [NSImage imageNamed:@"Editing-Text-icon.png"];
    _editorToolBoxViewController.textBackgroundColorSelector.icon = [NSImage imageNamed:@"Text-Marker.png"];

    // Timer
    
    _textMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(textMonitorEvent:) userInfo:nil repeats:YES];
    
    // Editor

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

    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@""
         "var enterKeyPressHandler = function(evt) {"
         "    evt = evt || window.event;"
         "    var charCode = evt.which || evt.keyCode;"
         "    if (charCode == 13) {"
         "        console.log('Enter key {');"
         "        var selection = document.getSelection();"
         "        var node = selection.anchorNode.parentNode;"
         "        if(node.tagName == 'BLOCKQUOTE') {"
         "            console.log('Splitting blockquote');"
         "            document.execCommand('insertHTML', false, '</blockquote><br><blockquote>');"
         "            evt.preventDefault();"
         "        }"
         "        console.log('Enter key }');"
         "    }"
         "};"
         "var el = document.getElementById('SimplicityEditor');"
         "if (typeof el.addEventListener != 'undefined')"
         "{"
         "    el.addEventListener('keypress', enterKeyPressHandler , false);"
         "}"
         "else if (typeof el.attachEvent != 'undefined')"
         "{"
         "    el.attachEvent('onkeypress', enterKeyPressHandler);"
         "}"];
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

- (NSString*)getFontTypeface:(NSInteger)index {
    if(index < 0 || index >= _editorToolBoxViewController.fontSelectionButton.numberOfItems) {
        return nil;
    }
    
    NSAssert(index >= 0 && index < fontNames.count, @"bad index %ld", index);
    
    return fontNames[index];
}

#pragma mark Editor

- (void)startEditor {
    NSString *htmlText = @""
        "<html>"
        "  <style>"
        "    blockquote {"
        "      display: block;"
        "      margin-top: 0em;"
        "      margin-bottom: 0em;"
        "      margin-left: 0em;"
        "      padding-left: 15px;"
        "      border-left: 4px solid #ccf;"
        "    }"
        "  </style>"
        "  <body id='SimplicityEditor'>"
        "  </body>"
        "</html>";

    [[_messageTextEditor mainFrame] loadHTMLString:htmlText baseURL:nil];
}

- (NSString*)getMessageText {
    return [(DOMHTMLElement *)[[[_messageTextEditor mainFrame] DOMDocument] documentElement] outerHTML];
}

- (void)textMonitorEvent:(NSTimer*)timer {
    //
    // Basic text attributes.
    //
    NSString *textStateString = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@""
      "(document.queryCommandState('bold')? 1 : 0) |"
      "(document.queryCommandState('italic')? 2 : 0) |"
      "(document.queryCommandState('underline')? 4 : 0)"];
                                 
    NSInteger textState = [textStateString integerValue];

    if(textState & 1) {
        [_editorToolBoxViewController.toggleBoldButton setTransparent:NO];
    } else {
        [_editorToolBoxViewController.toggleBoldButton setTransparent:YES];
    }
    
    if(textState & (1<<1)) {
        [_editorToolBoxViewController.toggleItalicButton setTransparent:NO];
    } else {
        [_editorToolBoxViewController.toggleItalicButton setTransparent:YES];
    }
    
    if(textState & (1<<2)) {
        [_editorToolBoxViewController.toggleUnderlineButton setTransparent:NO];
    } else {
        [_editorToolBoxViewController.toggleUnderlineButton setTransparent:YES];
    }
    
    //
    // Font name.
    //
    NSString *fontName = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('fontName')"];
    
    NSString *currentFontName = [self getFontTypeface:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];
    if(currentFontName == nil || ![currentFontName isEqualToString:fontName]) {
        NSNumber *fontIndexNum = [fontNameToIndexMap objectForKey:fontName];
        
        if(fontIndexNum != nil) {
            NSUInteger fontIndex = [fontIndexNum unsignedIntegerValue];
            NSAssert(fontIndex < fontFamilies.count, @"bad fontIndex %lu", fontIndex);
            
            [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:fontIndex];
        } else {
            [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:-1];
        }
    }
    
    //
    // Font size.
    //
    NSString *fontSize = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('fontSize')"];
    
    if(fontSize != nil) {
        NSInteger fontSizeNum = [fontSize integerValue];
        
        if(fontSizeNum >= 1 && fontSizeNum <= 7) {
            [_editorToolBoxViewController.textSizeButton selectItemAtIndex:fontSizeNum-1];
        } else {
            [_editorToolBoxViewController.textSizeButton selectItemAtIndex:-1];
        }
    } else {
        [_editorToolBoxViewController.textSizeButton selectItemAtIndex:-1];
    }

    //
    // Font color.
    //
    NSString *foreColorString = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('foreColor')"];
    NSString *backColorString = [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('backColor')"];

    NSColor *foreColor = [self colorFromString:foreColorString];
    NSColor *backColor = [self colorFromString:backColorString];

    if(foreColor != nil && ![_editorToolBoxViewController.textForegroundColorSelector.color isEqualTo:foreColor]) {
        [_editorToolBoxViewController.textForegroundColorSelector setColor:foreColor];
    }
    
    if(backColor != nil && ![_editorToolBoxViewController.textBackgroundColorSelector.color isEqualTo:backColor]) {
        [_editorToolBoxViewController.textBackgroundColorSelector setColor:backColor];
    }
}

- (NSColor*)colorFromString:(NSString*)colorString {
    NSScanner *colorScanner = [NSScanner scannerWithString:colorString];
    [colorScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] intoString:nil];
    
    NSInteger r,g,b;
    if([colorScanner scanInteger:&r] && [colorScanner scanString:@", " intoString:nil] &&
       [colorScanner scanInteger:&g] && [colorScanner scanString:@", " intoString:nil] &&
       [colorScanner scanInteger:&b])
    {
        NSInteger a = 255;
        if([colorString characterAtIndex:3] == 'a') {
            if(![colorScanner scanString:@", " intoString:nil] || ![colorScanner scanInteger:&a]) {
                a = 255;
            }
        }

        return [NSColor colorWithRed:(CGFloat)r/255 green:(CGFloat)g/255 blue:(CGFloat)b/255 alpha:(CGFloat)a/255];
    }
    else
    {
        return nil;
    }
}

#pragma mark Actions

//- (BOOL)windowShouldClose:(id)sender {
//    NSLog(@"%s", __func__);
//    return YES;
//}

- (void)windowWillClose:(NSNotification *)notification {
    [_textMonitorTimer invalidate];
    
    _textMonitorTimer = nil;
}

- (IBAction)sendAction:(id)sender {
    NSString *messageText = [self getMessageText];

    [_messageEditorController sendMessage:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];

	[self close];
}

- (IBAction)saveAction:(id)sender {
    NSString *messageText = [self getMessageText];
    
    [_messageEditorController saveDraft:messageText subject:_subjectField.stringValue to:_toBoxViewController.tokenField.stringValue cc:_ccBoxViewController.tokenField.stringValue bcc:_bccBoxViewController.tokenField.stringValue];
}

- (IBAction)attachAction:(id)sender {
    [self toggleAttachmentsPanel];
}

#pragma mark Text attrbitute actions

- (void)toggleBold {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('Bold')"];
}

- (void)toggleItalic {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('Italic')"];
}

- (void)toggleUnderline {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('Underline')"];
}

- (void)toggleBullets {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertUnorderedList')"];
}

- (void)toggleNumbering {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertOrderedList')"];
}

- (void)toggleQuote {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('formatBlock', false, 'blockquote')"];
}

- (void)shiftLeft {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('outdent')"];
}

- (void)shiftRight {
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:@"document.execCommand('indent')"];
}

- (void)selectFont {
    NSString *fontName = [self getFontTypeface:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];

    if(fontName != nil) {
        [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontName', false, '%@')", fontName]];
    } else {
        NSLog(@"%s: no selected font", __func__);
    }
}

- (void)setTextSize {
    NSInteger index = [_editorToolBoxViewController.textSizeButton indexOfSelectedItem];
    if(index < 0 || index >= _editorToolBoxViewController.textSizeButton.numberOfItems) {
        NSLog(@"%s: selected text size value index %ld is out of range", __func__, index);
        return;
    }

    NSInteger textSize = [[_editorToolBoxViewController.textSizeButton itemTitleAtIndex:index] integerValue];

    [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontSize', false, %ld)", textSize]];
}

- (void)justifyText {
    NSInteger index = [_editorToolBoxViewController.justifyTextControl selectedSegment];

    NSString *justifyFunc = nil;
    
    switch(index) {
        case 0: justifyFunc = @"justifyLeft"; break;
        case 1: justifyFunc = @"justifyCenter"; break;
        case 2: justifyFunc = @"justifyFull"; break;
        case 3: justifyFunc = @"justifyRight"; break;
        default: NSAssert(nil, @"Unexpected index %ld", index);
    }
    
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('%@', false)", justifyFunc]];
}

- (void)showSource {
    NSString *messageText = [self getMessageText];

    NSLog(@"%@", messageText);
}

- (NSString*)colorToHex:(NSColor*)color {
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(color.redComponent * 0xFF), (int)(color.greenComponent * 0xFF), (int)(color.blueComponent * 0xFF)];
}

- (void)setTextForegroundColor {
    NSString *hexString = [self colorToHex:_editorToolBoxViewController.textForegroundColorSelector.color];

    NSLog(@"%s: %@", __func__, hexString);

    [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('foreColor', false, '%@')", hexString]];
}

- (void)setTextBackgroundColor {
    NSString *hexString = [self colorToHex:_editorToolBoxViewController.textBackgroundColorSelector.color];
    
    NSLog(@"%s: %@", __func__, hexString);
    
    [_messageTextEditor stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('backColor', false, '%@')", hexString]];
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
/*
    NSLog(@"%s: TODO", __func__);
*/
    return WebDragDestinationActionEdit;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point {
    //NSLog(@"%s: TODO", __func__);
    return WebDragDestinationActionNone;
}

- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
/*
    NSLog(@"%s: TODO", __func__);

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
/*
    NSLog(@"%s: TODO", __func__);
*/
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action {
/*
    NSLog(@"%s: node '%@', range '%@'", __func__, node, range);
*/
    return YES;
}

@end
