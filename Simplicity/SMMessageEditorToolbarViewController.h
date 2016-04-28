//
//  SMMessageEditorToolbarViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/25/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageEditorViewController;

@interface SMMessageEditorToolbarViewController : NSViewController

@property __weak SMMessageEditorViewController *messageEditorViewController;

@property IBOutlet NSButton *sendButton;
@property IBOutlet NSButton *deleteButton;
@property IBOutlet NSButton *attachButton;

- (IBAction)sendAction:(id)sender;
- (IBAction)deleteAction:(id)sender;
- (IBAction)attachAction:(id)sender;

@end
