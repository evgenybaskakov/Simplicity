//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMMessageEditorView.h"

@class SMAddressFieldViewController;
@class SMLabeledTextFieldBoxViewController;
@class SMMessageEditorView;
@class SMInlineButtonPanelViewController;
@class SMMessageThreadViewController;
@class SMAttachmentsPanelViewController;

@interface SMMessageEditorViewController : NSViewController

@property (readonly) __weak SMMessageThreadViewController *messageThreadViewController;
@property (readonly) CGFloat editorFullHeight;
@property (readonly) Boolean hasUnsavedContents;
@property (readonly) Boolean plainText;

- (id)initWithFrame:(NSRect)frame messageThreadViewController:(SMMessageThreadViewController*)messageThreadViewController draftUid:(uint32_t)draftUid plainText:(Boolean)plainText;
- (void)setEditorFrame:(NSRect)frame;
- (void)setResponders:(BOOL)force;
- (void)startEditorWithHTML:(NSString*)messageHtmlBody subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc kind:(SMEditorContentsKind)editorKind mcoAttachments:(NSArray*)mcoAttachments;
- (void)makeHTMLText;
- (void)makePlainText;
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
- (void)toggleAttachmentsPanel:(SMAttachmentsPanelViewController*)sender;

@end
