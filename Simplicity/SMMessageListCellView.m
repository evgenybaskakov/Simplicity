//
//  SMMessageListCellView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMRoundedImageView.h"
#import "SMMessageListCellView.h"

@implementation SMMessageListCellView {
	Boolean _fieldsInitialized;
	Boolean _attachmentImageHidden;
}

- (void)initFields {
	if(_fieldsInitialized)
		return;
	
	NSFont *font = [_fromTextField font];
	
	font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait];
	
	[_fromTextField setFont:font];

    _contactImage.image = [NSImage imageNamed:NSImageNameUserGuest];
    _contactImage.cornerRadius = 3;
    _contactImage.borderWidth = 2;
    _contactImage.borderColor = [NSColor colorWithWhite:0.9 alpha:1];
    _contactImage.nonOriginalBehavior = YES;
    _contactImage.scaleImage = YES;
    
	_fieldsInitialized = true;
}

- (void)showContactImage {
    _fromTextFieldLeftContraint.constant = 49;
    _contactImage.hidden = NO;
}

- (void)hideContactImage {
    _fromTextFieldLeftContraint.constant = 5;
    _contactImage.hidden = YES;
}

- (void)showAttachmentImage {
	if(!_attachmentImageHidden)
		return;

    _subjectRightContraint.constant = 19;
    _attachmentImage.hidden = NO;
    _attachmentImageHidden = NO;
}

- (void)hideAttachmentImage {
	if(_attachmentImageHidden)
		return;

    _subjectRightContraint.constant = 1;
    _attachmentImage.hidden = YES;
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

+ (NSUInteger)heightForPreviewLines:(NSUInteger)linesCount {
    const NSUInteger baseHeight = 47;
    return baseHeight + linesCount * 16;
}

@end
