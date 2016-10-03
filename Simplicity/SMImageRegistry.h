//
//  SMImageRegistry.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/10/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMImageRegistry : NSObject

@property (readonly, nonatomic) NSImage *attachmentImage;
@property (readonly, nonatomic) NSImage *attachmentDocumentImage;
@property (readonly, nonatomic) NSImage *blueCircleImage;
@property (readonly, nonatomic) NSImage *yellowStarImage;
@property (readonly, nonatomic) NSImage *grayStarImage;
@property (readonly, nonatomic) NSImage *infoImage;
@property (readonly, nonatomic) NSImage *editImage;
@property (readonly, nonatomic) NSImage *replyImage;
@property (readonly, nonatomic) NSImage *replyAllImage;
@property (readonly, nonatomic) NSImage *replySmallImage;
@property (readonly, nonatomic) NSImage *replyAllSmallImage;
@property (readonly, nonatomic) NSImage *moreMessageActionsImage;

@end
