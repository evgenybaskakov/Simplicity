//
//  SMMessageEditorController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMAttachmentItem;

@interface SMMessageEditorController : NSObject

- (void)addAttachmentItem:(SMAttachmentItem*)attachmentItem;
- (void)sendMessage:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc;
- (void)saveDraft:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc;

@end
