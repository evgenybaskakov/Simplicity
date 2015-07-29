//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMLabeledTokenFieldBoxViewController;
@class SMLabeledTextFieldBoxViewController;
@class SMMessageEditorWebView;

@interface SMMessageEditorViewController : NSViewController

@property (readonly) SMLabeledTokenFieldBoxViewController *toBoxViewController;
@property (readonly) SMLabeledTokenFieldBoxViewController *ccBoxViewController;
@property (readonly) SMLabeledTokenFieldBoxViewController *bccBoxViewController;
@property (readonly) SMLabeledTextFieldBoxViewController *subjectBoxViewController;
@property (readonly) SMMessageEditorWebView *messageTextEditor;

@property (readonly) Boolean embedded;
@property (readonly) NSUInteger editorFullHeight;

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded;

- (void)sendMessage;
- (void)deleteMessage;
//- (void)saveMessage;
- (void)attachDocument;
- (void)toggleBold;
- (void)toggleItalic;
- (void)toggleUnderline;
- (void)toggleBullets;
- (void)toggleNumbering;
- (void)toggleQuote;
- (void)shiftLeft;
- (void)shiftRight;
- (void)selectFont;
- (void)setTextSize;
- (void)justifyText;
- (void)showSource;
- (void)setTextForegroundColor;
- (void)setTextBackgroundColor;
- (void)closeEditor;

@end
