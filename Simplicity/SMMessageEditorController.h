//
//  SMMessageEditorController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMAddress;
@class SMUserAccount;
@class SMAttachmentItem;

@interface SMMessageEditorController : NSObject

@property (readonly) Boolean hasSavedDraft;

@property Boolean hasUnsavedAttachments;

- (id)initWithDraftUID:(uint32_t)draftMessageUid;
- (void)addAttachmentItem:(SMAttachmentItem*)attachmentItem;
- (void)removeAttachmentItems:(NSArray*)attachmentItems;
- (void)sendMessage:(NSString*)messageText plainText:(Boolean)plainText subject:(NSString*)subject from:(SMAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc account:(SMUserAccount*)account;
- (void)saveDraft:(NSString*)messageText plainText:(Boolean)plainText subject:(NSString*)subject from:(SMAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc account:(SMUserAccount*)account;
- (void)deleteSavedDraft:(SMUserAccount*)account;

@end
