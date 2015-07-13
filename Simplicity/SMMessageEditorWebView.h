//
//  SMMessageEditorWebView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface SMMessageEditorWebView : WebView

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

// TODO: remove
- (NSString*)getFontTypeface:(NSInteger)index;

@end
