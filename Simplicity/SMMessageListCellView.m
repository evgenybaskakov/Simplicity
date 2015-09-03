//
//  SMMessageListCellView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageListCellView.h"

@implementation SMMessageListCellView {
	NSLayoutConstraint *_attachmentImageHiddenConstraint;
	Boolean _fieldsInitialized;
	Boolean _attachmentImageHidden;
}

- (void)initFields {
	if(_fieldsInitialized)
		return;
	
	NSFont *font = [_fromTextField font];
	
	font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait];
	
	[_fromTextField setFont:font];
	
	_fieldsInitialized = true;
}

- (void)showAttachmentImage {
	if(!_attachmentImageHidden)
		return;

	[self removeConstraint:_attachmentImageHiddenConstraint];
	
	[self addSubview:_attachmentImage];

	[self addConstraint:_attachmentImageLeftContraint];
	[self addConstraint:_attachmentImageRightContraint];
	[self addConstraint:_attachmentImageBottomContraint];

	_attachmentImageHidden = NO;
}

- (void)hideAttachmentImage {
	if(_attachmentImageHidden)
		return;
	
	[self removeConstraint:_attachmentImageLeftContraint];
	[self removeConstraint:_attachmentImageRightContraint];
	[self removeConstraint:_attachmentImageBottomContraint];

	[_attachmentImage removeFromSuperview];
	
	if(_attachmentImageHiddenConstraint == nil) {
		_attachmentImageHiddenConstraint = [NSLayoutConstraint constraintWithItem:_bookmarksView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_subjectTextField attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0];
	}

	[self addConstraint:_attachmentImageHiddenConstraint];
	
	_attachmentImageHidden = YES;
}

- (void)setMessagesCount:(NSUInteger)messagesCount {
    if(messagesCount == 1) {
        [_messagesCountButton setHidden:YES];
    }
    else {
        [_messagesCountButton setHidden:NO];
        [_messagesCountButton setTitle:[NSString stringWithFormat:@"%lu", messagesCount]];
    }
}

@end
