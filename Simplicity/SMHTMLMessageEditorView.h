//
//  SMMessageEditorView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

typedef enum {
    kFoldedReplyEditorContentsKind,
    kFoldedForwardEditorContentsKind,
    kUnfoldedReplyEditorContentsKind,
    kUnfoldedForwardEditorContentsKind,
    kUnfoldedDraftEditorContentsKind,
    kEmptyEditorContentsKind,
    kInvalidEditorContentsKind
} SMEditorContentsKind;

typedef enum {
    kEditorFocusKind_Content,
    kEditorFocusKind_Subject,
    kEditorFocusKind_ToAddress,
    kEditorFocusKind_Invalid
} SMEditorFocusKind;

@class SMMessageEditorBase;
@class SMEditorToolBoxViewController;

@interface SMHTMLMessageEditorView : WebView<WebFrameLoadDelegate, WebPolicyDelegate, WebResourceLoadDelegate, WebEditingDelegate>

@property __weak SMMessageEditorBase *messageEditorBase;
@property __weak SMEditorToolBoxViewController *editorToolBoxViewController;

@property (readonly) SMEditorContentsKind editorKind;
@property (readonly) NSUInteger contentHeight;
@property (readonly) NSUInteger stringOccurrencesCount;

@property BOOL unsavedContentPending;

+ (SMEditorFocusKind)contentKindToFocusKind:(SMEditorContentsKind)contentKind;

- (void)startEditorWithHTML:(NSString*)htmlContents kind:(SMEditorContentsKind)kind;
- (void)stopTextMonitor;
- (NSString*)getMessageText;
- (void)toggleBold;
- (void)toggleItalic;
- (void)toggleUnderline;
- (void)toggleBullets;
- (void)toggleNumbering;
- (void)toggleQuote;
- (void)shiftLeft;
- (void)shiftRight;
- (void)selectFont:(NSInteger)index;
- (void)setTextSize:(NSInteger)textSize;
- (void)justifyText:(NSInteger)index;
- (void)setTextForegroundColor:(NSColor*)color;
- (void)setTextBackgroundColor:(NSColor*)color;
- (void)showSource;
- (void)unfoldContent;

// TODO: remove
- (NSString*)getFontTypeface:(NSInteger)index;

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase;
- (void)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;
- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement;
- (void)animatedScrollToMarkedOccurrence;

@end
