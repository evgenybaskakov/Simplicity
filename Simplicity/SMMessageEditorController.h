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

@property (readonly) Boolean hasSavedDraft;

@property Boolean hasUnsavedAttachments;

- (id)initWithDraftUID:(uint32_t)draftMessageUid;
- (void)addAttachmentItem:(SMAttachmentItem*)attachmentItem;
- (void)removeAttachmentItems:(NSArray*)attachmentItems;
- (void)sendMessage:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc;
- (void)saveDraft:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc;
- (void)deleteSavedDraft;

@end
