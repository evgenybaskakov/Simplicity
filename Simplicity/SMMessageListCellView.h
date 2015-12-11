//
//  SMMessageListCellView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMRoundedImageView;
@class SMMessageBookmarksView;

@interface SMMessageListCellView : NSTableCellView

@property IBOutlet SMRoundedImageView *contactImage;

@property IBOutlet NSTextField *fromTextField;
@property IBOutlet NSLayoutConstraint *fromTextFieldLeftContraint;
@property IBOutlet NSLayoutConstraint *subjectRightContraint;

@property (weak) IBOutlet NSTextField *messagePreviewTextField;
@property (weak) IBOutlet NSTextField *subjectTextField;
@property (weak) IBOutlet NSTextField *dateTextField;
@property (weak) IBOutlet NSButton *unseenButton;
@property (weak) IBOutlet NSButton *starButton;
@property (weak) IBOutlet SMMessageBookmarksView *bookmarksView;

@property IBOutlet NSButton *messagesCountButton;
@property IBOutlet NSImageView *attachmentImage;

@property uint64_t messageThreadId;

- (void)initFields;

- (void)showContactImage;
- (void)hideContactImage;

- (void)showAttachmentImage;
- (void)hideAttachmentImage;

- (void)setMessagesCount:(NSUInteger)messagesCount;

+ (NSUInteger)heightForPreviewLines:(NSUInteger)linesCount;

@end
