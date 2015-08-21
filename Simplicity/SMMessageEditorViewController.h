//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMMessageEditorWebView.h"

@class SMLabeledTokenFieldBoxViewController;
@class SMLabeledTextFieldBoxViewController;
@class SMMessageEditorWebView;
@class SMInlineButtonPanelViewController;

@interface SMMessageEditorViewController : NSViewController

@property (readonly) Boolean embedded;
@property (readonly) NSUInteger editorFullHeight;

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded draftUid:(uint32_t)draftUid;
- (void)setEditorFrame:(NSRect)frame;
- (void)setResponders;
- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind;
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
- (void)closeEditor:(Boolean)saveDraft;

@end
