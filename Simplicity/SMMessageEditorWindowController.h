//
//  SMMessageEditorWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageEditorViewController;

@interface SMMessageEditorWindowController : NSWindowController<NSWindowDelegate>

@property (readonly) SMMessageEditorViewController *messageEditorViewController;

- (void)setHtmlContents:(NSString*)htmlContents;

@end
