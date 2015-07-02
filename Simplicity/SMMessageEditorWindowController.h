//
//  SMMessageEditorWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView;

@class SMLabeledTokenFieldBoxView;
@class SMLabeledTokenFieldBoxViewController;

@interface SMMessageEditorWindowController : NSWindowController<NSWindowDelegate>

@property IBOutlet NSButton *sendButton;
@property IBOutlet NSButton *saveButton;
@property IBOutlet NSButton *attachButton;
@property IBOutlet NSView *toBoxView;
@property IBOutlet NSView *ccBoxView;
@property IBOutlet NSView *bccBoxView;
@property IBOutlet NSTextField *subjectField;
@property IBOutlet WebView *messageTextEditor;
@property IBOutlet NSButton *toggleBoldButton;
@property IBOutlet NSButton *toggleItalicButton;
@property IBOutlet NSButton *toggleUnderlineButton;
@property IBOutlet NSButton *toggleBulletsButton;
@property IBOutlet NSButton *toggleNumberingButton;
@property IBOutlet NSButton *toggleQuoteButton;
@property IBOutlet NSButton *shiftLeftButton;
@property IBOutlet NSButton *shiftRightButton;
@property IBOutlet NSPopUpButton *textSizeButton;
@property IBOutlet NSPopUpButton *justifyButton;
@property IBOutlet NSButton *showSourceButton;
@property IBOutlet NSLayoutConstraint *messageEditorBottomConstraint;

@property SMLabeledTokenFieldBoxViewController *toBoxViewController;
@property SMLabeledTokenFieldBoxViewController *ccBoxViewController;
@property SMLabeledTokenFieldBoxViewController *bccBoxViewController;

- (IBAction)sendAction:(id)sender;
- (IBAction)saveAction:(id)sender;
- (IBAction)attachAction:(id)sender;
- (IBAction)toggleBoldAction:(id)sender;
- (IBAction)toggleItalicAction:(id)sender;
- (IBAction)toggleUnderlineAction:(id)sender;
- (IBAction)setTextSizeAction:(id)sender;
- (IBAction)justifyTextAction:(id)sender;
- (IBAction)showSourceAction:(id)sender;

@end
