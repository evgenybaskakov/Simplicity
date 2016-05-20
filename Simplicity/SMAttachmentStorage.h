//
//  SMMessageAttachmentStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@interface SMAttachmentStorage : SMUserAccountDataObject

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)storeAttachment:(NSData*)data folder:(NSString*)folder uid:(uint32_t)uid contentId:(NSString*)contentId;
- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder;

@end
