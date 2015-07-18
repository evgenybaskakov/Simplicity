//
//  SMEditorToolBoxViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/11/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageEditorViewController;
@class SMColorWellWithIcon;

@interface SMEditorToolBoxViewController : NSViewController

@property __weak SMMessageEditorViewController *messageEditorViewController;

@property IBOutlet NSButton *sendButton;
//@property IBOutlet NSButton *saveButton;
@property IBOutlet NSButton *attachButton;
@property IBOutlet NSSegmentedControl *textStyleButton;
@property IBOutlet SMColorWellWithIcon *textForegroundColorSelector;
@property IBOutlet SMColorWellWithIcon *textBackgroundColorSelector;
@property IBOutlet NSSegmentedControl *toggleListButton;
@property IBOutlet NSButton *toggleQuoteButton;
@property IBOutlet NSSegmentedControl *shiftButton;
@property IBOutlet NSPopUpButton *fontSelectionButton;
@property IBOutlet NSPopUpButton *textSizeButton;
@property IBOutlet NSSegmentedControl *justifyTextControl;
@property IBOutlet NSButton *showSourceButton;

- (IBAction)sendAction:(id)sender;
//- (IBAction)saveAction:(id)sender;
- (IBAction)attachAction:(id)sender;
- (IBAction)setTextStyleAction:(id)sender;
- (IBAction)toggleListAction:(id)sender;
- (IBAction)toggleQuoteAction:(id)sender;
- (IBAction)shiftAction:(id)sender;
- (IBAction)selectFontAction:(id)sender;
- (IBAction)setTextSizeAction:(id)sender;
- (IBAction)justifyTextAction:(id)sender;
- (IBAction)showSourceAction:(id)sender;
- (IBAction)setTextForegroundColorAction:(id)sender;
- (IBAction)setTextBackgroundColorAction:(id)sender;

@end
