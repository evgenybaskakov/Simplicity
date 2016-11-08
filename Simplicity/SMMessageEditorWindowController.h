//
//  SMMessageEditorWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMMessageEditorView.h"

@class SMAddress;
@class SMMessageEditorViewController;

@interface SMMessageEditorWindowController : NSWindowController<NSWindowDelegate>

@property (readonly) SMMessageEditorViewController *messageEditorViewController;

- (void)initHtmlContents:(NSString*)textContent plainText:(BOOL)plainText subject:(NSString*)subject to:(NSArray<SMAddress*>*)to cc:(NSArray<SMAddress*>*)cc bcc:(NSArray<SMAddress*>*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments editorKind:(SMEditorContentsKind)editorKind;

@end
