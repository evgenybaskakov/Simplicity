//
//  SMMessageEditorWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView;

@interface SMMessageEditorWindowController : NSWindowController<NSWindowDelegate>

@property IBOutlet WebView *messageTextEditor;

@end
