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

- (void)initHtmlContents:(NSString*)textContent plainText:(Boolean)plainText subject:(NSString*)subject to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc draftUid:(uint32_t)draftUid mcoAttachments:(NSArray*)mcoAttachments;

@end
