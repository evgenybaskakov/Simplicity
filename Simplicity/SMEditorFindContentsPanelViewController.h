//
//  SMEditorFindContentsPanelViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageEditorViewController;

@interface SMEditorFindContentsPanelViewController : NSViewController

@property (weak) IBOutlet NSSearchField *findField;
@property (weak) IBOutlet NSTextField *replaceField;

@property (weak) SMMessageEditorViewController *messageEditorViewController;

@end
