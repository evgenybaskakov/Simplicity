//
//  SMMessageEditorViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/13/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMLabeledTokenFieldBoxView;
@class SMLabeledTokenFieldBoxViewController;
@class SMMessageEditorWebView;

@interface SMMessageEditorViewController : NSViewController

@property IBOutlet NSView *toBoxView;
@property IBOutlet NSView *ccBoxView;
@property IBOutlet NSView *bccBoxView;
@property IBOutlet NSView *subjectView;
@property IBOutlet NSTextField *subjectField;
@property IBOutlet NSView *editorToolBoxView;
@property IBOutlet SMMessageEditorWebView *messageTextEditor;

@property IBOutlet NSLayoutConstraint *toTopConstraint;
@property IBOutlet NSLayoutConstraint *toLeadingConstraint;
@property IBOutlet NSLayoutConstraint *toTrailingConstraint;

@property IBOutlet NSLayoutConstraint *ccTopConstraint;
@property IBOutlet NSLayoutConstraint *ccLeadingConstraint;
@property IBOutlet NSLayoutConstraint *ccTrailingConstraint;

@property IBOutlet NSLayoutConstraint *bccTopConstraint;
@property IBOutlet NSLayoutConstraint *bccLeadingConstraint;
@property IBOutlet NSLayoutConstraint *bccTrailingConstraint;

@property IBOutlet NSLayoutConstraint *subjectTopConstraint;
@property IBOutlet NSLayoutConstraint *subjectLeadingConstraint;
@property IBOutlet NSLayoutConstraint *subjectTrailingConstraint;

@property IBOutlet NSLayoutConstraint *toolboxTopConstraint;
@property IBOutlet NSLayoutConstraint *toolboxLeadingConstraint;
@property IBOutlet NSLayoutConstraint *toolboxTrailingConstraint;

@property IBOutlet NSLayoutConstraint *messageEditorTopConstraint;
@property IBOutlet NSLayoutConstraint *messageEditorLeadingConstraint;
@property IBOutlet NSLayoutConstraint *messageEditorTrailingConstraint;
@property IBOutlet NSLayoutConstraint *messageEditorBottomConstraint;

@property SMLabeledTokenFieldBoxViewController *toBoxViewController;
@property SMLabeledTokenFieldBoxViewController *ccBoxViewController;
@property SMLabeledTokenFieldBoxViewController *bccBoxViewController;

@property Boolean embedded;

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil embedded:(Boolean)embedded;

- (void)sendMessage;
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
