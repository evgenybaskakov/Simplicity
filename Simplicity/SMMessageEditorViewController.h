//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMMessageEditorWebView.h"

@class SMAddressFieldViewController;
@class SMLabeledTextFieldBoxViewController;
@class SMMessageEditorWebView;
@class SMInlineButtonPanelViewController;

@interface SMMessageEditorViewController : NSViewController

@property (readonly) Boolean embedded;
@property (readonly) CGFloat editorFullHeight;
@property (readonly) Boolean hasUnsavedContents;

- (id)initWithFrame:(NSRect)frame embedded:(Boolean)embedded draftUid:(uint32_t)draftUid;
- (void)setEditorFrame:(NSRect)frame;
- (void)setResponders:(BOOL)force;
- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments;
- (void)sendMessage;
- (void)deleteEditedDraft;
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
- (void)closeEditor:(Boolean)shouldSaveDraft;
- (void)saveDocument:(id)sender;

@end
