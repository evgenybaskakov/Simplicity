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

@interface SMMessageEditorWindowController : NSWindowController

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

@end
