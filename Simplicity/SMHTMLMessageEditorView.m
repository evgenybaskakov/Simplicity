//
//  SMMessageEditorView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMColorWellWithIcon.h"
#import "SMMessageEditorBase.h"
#import "SMEditorToolBoxViewController.h"
#import "SMHTMLFindContext.h"
#import "SMHTMLMessageEditorView.h"

@implementation SMHTMLMessageEditorView {
    NSTimer *_textMonitorTimer;
    NSUInteger _cachedContentHeight;
    SMHTMLFindContext *_findContext;
}

+ (SMEditorFocusKind)contentKindToFocusKind:(SMEditorContentsKind)contentKind {
    switch(contentKind) {
        case kFoldedReplyEditorContentsKind:
        case kUnfoldedReplyEditorContentsKind:
        case kUnfoldedDraftEditorContentsKind:
            return kEditorFocusKind_Content;
        case kFoldedForwardEditorContentsKind:
        case kUnfoldedForwardEditorContentsKind:
            return kEditorFocusKind_ToAddress;
        case kEmptyEditorContentsKind:
            return kEditorFocusKind_Subject;
        default:
            SM_FATAL(@"unknown editor contents kind %u", contentKind);
            return 0;
    }
}

+ (BOOL)kindToFocusOnToAddress:(SMEditorContentsKind)kind {
    return kind == kUnfoldedForwardEditorContentsKind;
}

- (id)init {
    self = [super init];
    
    if(self) {
        [self initWebView];
    }
    
    return self;
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    
    if(self) {
        [self initWebView];
    }
    
    return self;
}

- (void)dealloc {
    [self stopLoading:self];
}

- (void)initWebView {
    [self setFrameLoadDelegate:self];
    [self setPolicyDelegate:self];
    [self setResourceLoadDelegate:self];
    [self setEditingDelegate:self];
    [self setCanDrawConcurrently:YES];
    [self setEditable:YES];
}

- (void)startEditorWithHTML:(NSString*)htmlContents kind:(SMEditorContentsKind)kind {
    _textMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(textMonitorEvent:) userInfo:nil repeats:YES];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSString *signature = nil;
    
    if([[appDelegate preferencesController] shouldUseSingleSignature]) {
        signature = [[appDelegate preferencesController] singleSignature];
    }
    else {
        signature = [[appDelegate preferencesController] accountSignature:(appDelegate.currentAccountIsUnified? 0 : appDelegate.currentAccountIdx)];
    }
    
    NSString *signatureText = signature? [NSString stringWithFormat:@"<br/>%@", signature] : @"";
    NSString *bodyHtml = nil;
    
    if(kind == kEmptyEditorContentsKind) {
        bodyHtml = [NSString stringWithFormat:@"%@%@%@", [SMMessageEditorBase newUnfoldedMessageHTMLBeginTemplate], signatureText, [SMMessageEditorBase newMessageHTMLEndTemplate], nil];
    }
    else {
        if(htmlContents == nil) {
            bodyHtml = @"";

            if(kind == kFoldedForwardEditorContentsKind) {
                kind = kFoldedReplyEditorContentsKind;
            }
            else if(kind == kUnfoldedForwardEditorContentsKind) {
                kind = kUnfoldedReplyEditorContentsKind;
            }
        }
        else {
            if(kind == kFoldedReplyEditorContentsKind || kind == kFoldedForwardEditorContentsKind) {
                bodyHtml = [NSString stringWithFormat:@"%@%@<br><br><br><blockquote>%@</blockquote>%@", [SMMessageEditorBase newFoldedMessageHTMLBeginTemplate], signatureText, htmlContents, [SMMessageEditorBase newMessageHTMLEndTemplate], nil];
            }
            else if(kind == kUnfoldedReplyEditorContentsKind || kind == kUnfoldedForwardEditorContentsKind) {
                bodyHtml = [NSString stringWithFormat:@"%@%@<br><br><br><blockquote>%@</blockquote>%@", [SMMessageEditorBase newUnfoldedMessageHTMLBeginTemplate], signatureText, htmlContents, [SMMessageEditorBase newMessageHTMLEndTemplate], nil];
            }
            else if(kind == kUnfoldedDraftEditorContentsKind) {
                // TODO: may need to adjust the HTML body id (set "SimplicityEditor" stuff, etc...)
                bodyHtml = htmlContents;
            }
            else {
                SM_FATAL(@"unknown editor contents kind %u", kind);
            }
        }
    }
    
    _editorKind = kind;

    [self.mainFrame loadHTMLString:bodyHtml baseURL:nil];
}

- (void)stopTextMonitor {
    [_textMonitorTimer invalidate];    
    _textMonitorTimer = nil;
}

- (NSString*)getFontTypeface:(NSInteger)index {
    if(index < 0 || index >= [SMMessageEditorBase fontNames].count) {
        return nil;
    }
    
    return [SMMessageEditorBase fontNames][index];
}

#pragma mark Web frame contents

- (NSString*)getMessageText {
    return [(DOMHTMLElement *)[[self.mainFrame DOMDocument] documentElement] outerHTML];
}

#pragma mark Web view control

- (void)webViewDidChange:(NSNotification *)notification {
    if(self.undoManager.undoing || self.undoManager.redoing) {
        [self animatedScrollTo:self.selectedDOMRange.startContainer.boundingBox.origin.y];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if(sender != nil && frame == sender.mainFrame) {
        SM_LOG_INFO(@"editor document main frame loaded");

        _findContext = nil;

        SMEditorFocusKind focusKind = [SMHTMLMessageEditorView contentKindToFocusKind:_editorKind];
        if(focusKind == kEditorFocusKind_Content) {
            WebScriptObject *scriptObject = [self windowScriptObject];
            [scriptObject evaluateWebScript:@"document.getElementById('SimplicityEditor').focus()"];
        }

        [self setCachedContentHeight];
        [self notifyContentHeightChanged];
    }

    if (frame == [frame findFrameNamed:@"_top"]) {
        //
        // Bridge between JavaScript's console.log and Cocoa NSLog
        // http://jerodsanto.net/2010/12/bridging-the-gap-between-javascripts-console-log-and-cocoas-nslog/
        //
        WebScriptObject *scriptObject = [sender windowScriptObject];
        
        [scriptObject setValue:self forKey:@"Simplicity"];
        
        [scriptObject evaluateWebScript:@"console = { log: function(msg) { Simplicity.consoleLog_(msg); } }"];
        
        [scriptObject evaluateWebScript:@"eventCallback = { eventInput: function(msg) { Simplicity.eventInput_(msg); } }"];

        [scriptObject evaluateWebScript:@""
             "jsNotifyContentHeightChanged = function() {"
             "    var body = document.body;"
             "    var html = document.documentElement;"
             "    var height = Math.max(body.scrollHeight, body.offsetHeight, html.clientHeight, html.scrollHeight, html.offsetHeight);"
             "    eventCallback.eventInput(height);"
             "}"];
    
        [scriptObject evaluateWebScript:@""
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
             "}"
             "document.getElementById('SimplicityEditor').addEventListener('input', jsNotifyContentHeightChanged, false);"];
    }
}

- (void)consoleLog:(NSString *)message {
    SM_LOG_INFO(@"JSLog: %@", message);
}

- (void)eventInput:(NSString *)heightString {
    NSUInteger height = [heightString integerValue];
    SM_LOG_DEBUG(@"eventInput: contentHeight %ld", height);
    
    if(height != _cachedContentHeight) {
        _cachedContentHeight = height;

        [self notifyContentHeightChanged];
    }
    
    _unsavedContentPending = YES;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
    if (aSelector == @selector(consoleLog:) || aSelector == @selector(eventInput:)) {
        return NO;
    }
    
    return YES;
}

- (void)notifyContentHeightChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageEditorContentHeightChanged" object:nil userInfo:nil];
}

- (void)setCachedContentHeight {
    WebFrame *mainFrame = [self mainFrame];
    
    if(mainFrame != nil) {
        // TODO: remove duplication, see SMMessageBodyViewController.contentHeight
        _cachedContentHeight = [[[mainFrame frameView] documentView] frame].size.height;
        SM_LOG_DEBUG(@"_cachedContentHeight: %ld", _cachedContentHeight);
    }
}

- (NSUInteger)contentHeight {
    if(_cachedContentHeight == 0) {
        [self setCachedContentHeight];
    }
    
    return _cachedContentHeight;
}

#pragma mark Web view policies

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    if ([actionInformation objectForKey:WebActionElementKey]) {
        [listener ignore];
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    } else {
        [listener use];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

#pragma mark Drag and drop to HTML editor

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    /*
     SM_LOG_DEBUG(@"TODO");
     */
    return WebDragDestinationActionEdit;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point {
    SM_LOG_DEBUG(@"TODO");
    return WebDragDestinationActionNone;
}

- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id<NSDraggingInfo>)draggingInfo {
    /*
     SM_LOG_DEBUG(@"TODO");
     
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
     
     SM_LOG_DEBUG(@"html: %@", html);
     }
     }
     */
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard {
    /*
     SM_LOG_DEBUG(@"TODO");
     */
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action {
    /*
     SM_LOG_DEBUG(@"node '%@', range '%@'", node, range);
     */
    return YES;
}

- (void)textMonitorEvent:(NSTimer*)timer {
    //
    // Basic text attributes.
    //
    NSString *textStateString = [self stringByEvaluatingJavaScriptFromString:@""
                                 "(document.queryCommandState('bold')? 1 : 0) |"
                                 "(document.queryCommandState('italic')? 2 : 0) |"
                                 "(document.queryCommandState('underline')? 4 : 0)"];
    
    NSInteger textState = [textStateString integerValue];

    [_editorToolBoxViewController.textStyleButton setSelected:((textState & (1<<0)) != 0) forSegment:0];
    [_editorToolBoxViewController.textStyleButton setSelected:((textState & (1<<1)) != 0) forSegment:1];
    [_editorToolBoxViewController.textStyleButton setSelected:((textState & (1<<2)) != 0) forSegment:2];
    
    //
    // Font name.
    //
    NSString *fontName = [self stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('fontName')"];
    
    NSString *currentFontName = [self getFontTypeface:[_editorToolBoxViewController.fontSelectionButton indexOfSelectedItem]];
    if(currentFontName == nil || ![currentFontName isEqualToString:fontName]) {
        NSNumber *fontIndexNum = [[SMMessageEditorBase fontNameToIndexMap] objectForKey:fontName];
        
        if(fontIndexNum != nil) {
            NSUInteger fontIndex = [fontIndexNum unsignedIntegerValue];
            NSAssert(fontIndex < [SMMessageEditorBase fontFamilies].count, @"bad fontIndex %lu", fontIndex);
            
            [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:fontIndex];
        } else {
            [_editorToolBoxViewController.fontSelectionButton selectItemAtIndex:-1];
        }
    }
    
    //
    // Font size.
    //
    NSString *fontSize = [self stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('fontSize')"];
    
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
    NSString *foreColorString = [self stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('foreColor')"];
    NSString *backColorString = [self stringByEvaluatingJavaScriptFromString:@"document.queryCommandValue('backColor')"];
    
    NSColor *foreColor = [_messageEditorBase colorFromString:foreColorString];
    NSColor *backColor = [_messageEditorBase colorFromString:backColorString];
    
    if(foreColor != nil && ![_editorToolBoxViewController.textForegroundColorSelector.color isEqualTo:foreColor]) {
        [_editorToolBoxViewController.textForegroundColorSelector setColor:foreColor];
    }
    
    if(backColor != nil && ![_editorToolBoxViewController.textBackgroundColorSelector.color isEqualTo:backColor]) {
        [_editorToolBoxViewController.textBackgroundColorSelector setColor:backColor];
    }
}

#pragma mark Content queries and modifications

- (void)toggleBold {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Bold')"];
    
    _unsavedContentPending = YES;
}

- (void)toggleItalic {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Italic')"];
    
    _unsavedContentPending = YES;
}

- (void)toggleUnderline {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Underline')"];
    
    _unsavedContentPending = YES;
}

- (void)toggleBullets {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertUnorderedList')"];
    
    _unsavedContentPending = YES;
}

- (void)toggleNumbering {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertOrderedList')"];
    
    _unsavedContentPending = YES;
}

- (void)toggleQuote {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('formatBlock', false, 'blockquote')"];
    
    _unsavedContentPending = YES;
}

- (void)shiftLeft {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('outdent')"];
    
    _unsavedContentPending = YES;
}

- (void)shiftRight {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('indent')"];
    
    _unsavedContentPending = YES;
}

- (void)selectFont:(NSInteger)index {
    NSString *fontName = [self getFontTypeface:index];
    
    if(fontName != nil) {
        [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontName', false, '%@')", fontName]];
        
        _unsavedContentPending = YES;
    } else {
        SM_LOG_DEBUG(@"no selected font");
    }
}

- (void)setTextSize:(NSInteger)textSize {
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontSize', false, %ld)", textSize]];
    
    _unsavedContentPending = YES;
}

- (void)justifyText:(NSInteger)index {    
    NSString *justifyFunc = nil;
    
    switch(index) {
        case 0: justifyFunc = @"justifyLeft"; break;
        case 1: justifyFunc = @"justifyCenter"; break;
        case 2: justifyFunc = @"justifyFull"; break;
        case 3: justifyFunc = @"justifyRight"; break;
        default: NSAssert(nil, @"Unexpected index %ld", index);
    }
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('%@', false)", justifyFunc]];

    _unsavedContentPending = YES;
}

- (NSString*)colorToHex:(NSColor*)color {
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(color.redComponent * 0xFF), (int)(color.greenComponent * 0xFF), (int)(color.blueComponent * 0xFF)];
}

- (void)setTextForegroundColor:(NSColor*)color {
    NSString *hexString = [self colorToHex:color];
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('foreColor', false, '%@')", hexString]];

    _unsavedContentPending = YES;
}

- (void)setTextBackgroundColor:(NSColor*)color {
    NSString *hexString = [self colorToHex:color];
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('backColor', false, '%@')", hexString]];

    _unsavedContentPending = YES;
}

- (void)showSource {
    NSString *messageText = [self getMessageText];
    
    SM_LOG_DEBUG(@"%@", messageText);
}

#pragma mark Content folding

- (void)unfoldContent {
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@""
        "var el = document.getElementById('SimplicityContentToFold');"
        "el.style.display = '';"
        "jsNotifyContentHeightChanged();"]];
}

#pragma mark Finding contents

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    if(!_findContext) {
        _findContext = [[SMHTMLFindContext alloc] initWithDocument:self.mainFrameDocument webview:self];
    }
    
    [_findContext highlightAllOccurrencesOfString:str matchCase:matchCase];
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
    [_findContext markOccurrenceOfFoundString:index];
}

- (NSUInteger)stringOccurrencesCount {
    return _findContext.stringOccurrencesCount;
}

- (void)removeMarkedOccurrenceOfFoundString {
    [_findContext removeMarkedOccurrenceOfFoundString];
}

- (void)removeAllHighlightedOccurrencesOfString {
    [_findContext removeAllHighlightedOccurrencesOfString];
}

- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement {
    if(_findContext.stringOccurrencesCount != 0) {
        _unsavedContentPending = YES;
    }
    
    [_findContext replaceOccurrence:index replacement:replacement];
}

- (void)replaceAllOccurrences:(NSString*)replacement {
    if(_findContext.stringOccurrencesCount != 0) {
        _unsavedContentPending = YES;
    }

    [_findContext replaceAllOccurrences:replacement];
}

- (void)animatedScrollToMarkedOccurrence {
    [self animatedScrollTo:_findContext.markedOccurrenceYpos];
}

- (void)animatedScrollTo:(CGFloat)ypos {
    // http://stackoverflow.com/questions/7020842/disable-rubber-band-scrolling-for-webview-in-lion/11820479#11820479
    NSScrollView *sv = self.mainFrame.frameView.documentView.enclosingScrollView;
    
    NSRect documentVisibleRect = [[sv contentView] documentVisibleRect];
    
    const NSUInteger delta = 50;
    if(ypos < documentVisibleRect.origin.y + delta || ypos >= documentVisibleRect.origin.y + documentVisibleRect.size.height - delta) {
        CGFloat adjustedGlobalYpos = ypos - delta;
        if(adjustedGlobalYpos < delta) {
            adjustedGlobalYpos = 0;
        }
        
        NSRect cellRect = NSMakeRect(sv.visibleRect.origin.x, adjustedGlobalYpos, sv.visibleRect.size.width, sv.visibleRect.size.height);
        NSClipView *clipView = [sv contentView];
        NSRect constrainedRect = [clipView constrainBoundsRect:cellRect];
        [NSAnimationContext beginGrouping];
        [[clipView animator] setBoundsOrigin:constrainedRect.origin];
        [NSAnimationContext endGrouping];
        
        [sv reflectScrolledClipView:clipView];
    }
}

@end
