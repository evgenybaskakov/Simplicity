//
//  SMMessageAttachmentStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMUserAccount;

@interface SMAttachmentStorage : NSObject

- (void)storeAttachment:(NSData*)data folder:(NSString*)folder uid:(uint32_t)uid contentId:(NSString*)contentId filename:(NSString*)filename account:(SMUserAccount*)account;
- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder account:(SMUserAccount*)account;
- (NSURL*)draftAttachmentLocation:(NSString*)contentId;

@end
