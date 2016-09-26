//
//  SMMessageEditorWebView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

typedef enum {
    kFoldedReplyEditorContentsKind,
    kUnfoldedReplyEditorContentsKind,
    kUnfoldedDraftEditorContentsKind,
    kEmptyEditorContentsKind,
} SMEditorContentsKind;

@class SMMessageEditorBase;
@class SMEditorToolBoxViewController;

@interface SMMessageEditorWebView : WebView<WebFrameLoadDelegate, WebPolicyDelegate, WebResourceLoadDelegate, WebEditingDelegate>

@property __weak SMMessageEditorBase *messageEditorBase;
@property __weak SMEditorToolBoxViewController *editorToolBoxViewController;

@property (readonly) NSUInteger contentHeight;

@property Boolean unsavedContentPending;

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

@end
