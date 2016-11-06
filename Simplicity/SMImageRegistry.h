//
//  SMImageRegistry.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/10/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMImageRegistry : NSObject

@property (readonly) NSImage *attachmentImage;
@property (readonly) NSImage *attachmentDocumentImage;
@property (readonly) NSImage *blueCircleImage;
@property (readonly) NSImage *yellowStarImage;
@property (readonly) NSImage *grayStarImage;
@property (readonly) NSImage *infoImage;
@property (readonly) NSImage *editImage;
@property (readonly) NSImage *replyImage;
@property (readonly) NSImage *replyAllImage;
@property (readonly) NSImage *replySmallImage;
@property (readonly) NSImage *replyAllSmallImage;
@property (readonly) NSImage *moreMessageActionsImage;
@property (readonly) NSImage *unifiedAccountImage;

@end
