//
//  SMImageRegistry.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/10/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMImageRegistry.h"

@implementation SMImageRegistry

- (id)init {
    self = [super init];
    
    if(self) {
        _attachmentImage = [NSImage imageNamed:@"attachment.png"];
        _attachmentDocumentImage = [NSImage imageNamed:@"attachment-document.png"];
        _blueCircleImage = [NSImage imageNamed:@"circle-blue.png"];
        _yellowStarImage = [NSImage imageNamed:@"star-yellow.png"];
        _grayStarImage = [NSImage imageNamed:@"star-gray.png"];
        _editImage = [NSImage imageNamed:@"edit.png"];
        _infoImage = [NSImage imageNamed:@"info.png"];
        _replyImage = [NSImage imageNamed:@"reply.png"];
        _replyAllImage = [NSImage imageNamed:@"reply-all.png"];
        _replySmallImage = [NSImage imageNamed:@"reply.png"];
        _replyAllSmallImage = [NSImage imageNamed:@"reply-all.png"];
        _moreMessageActionsImage = [NSImage imageNamed:@"iconsineed-icon-down-128.png"];
    }
    
    return self;
}

@end
