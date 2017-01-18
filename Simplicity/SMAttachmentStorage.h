//
//  SMMessageAttachmentStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessage;
@class SMUserAccount;

@interface SMAttachmentStorage : NSObject

- (BOOL)storeAttachment:(NSData*)data folder:(NSString*)folder uid:(uint32_t)uid contentId:(NSString*)contentId filename:(NSString*)filename account:(SMUserAccount*)account;
- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder account:(SMUserAccount*)account;

- (BOOL)storeDraftInlineAttachment:(NSURL*)fileUrl contentId:(NSString*)contentId;
- (NSURL*)draftInlineAttachmentLocation:(NSString*)contentId;

- (void)fetchMessageInlineAttachments:(SMMessage*)message account:(SMUserAccount*)account;

@end
