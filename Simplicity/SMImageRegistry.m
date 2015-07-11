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
		_attachmentImage = [NSImage imageNamed:@"attachment-icon.png"];
		_attachmentDocumentImage = [NSImage imageNamed:@"attachment-document.png"];
		_blueCircleImage = [NSImage imageNamed:@"circle-blue.png"];
		_yellowStarImage = [NSImage imageNamed:@"star-yellow-icon.png"];
		_grayStarImage = [NSImage imageNamed:@"star-gray-icon.png"];
		_infoImage = [NSImage imageNamed:@"info-icon.png"];
        _replyImage = [NSImage imageNamed:@"iconsineed-icon-reply-128.png"];
        _replyAllImage = [NSImage imageNamed:@"iconsineed-icon-reply-all-128.png"];
        _moreMessageActionsImage = [NSImage imageNamed:@"iconsineed-icon-down-128.png"];
	}
	
	return self;
}

@end
