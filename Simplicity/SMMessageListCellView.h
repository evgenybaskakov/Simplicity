//
//  SMMessageListCellView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageBookmarksView;

@interface SMMessageListCellView : NSTableCellView

@property IBOutlet NSImageView *contactImage;

@property IBOutlet NSTextField *fromTextField;
@property IBOutlet NSLayoutConstraint *fromTextFieldLeftContraint;

@property (weak) IBOutlet NSTextField *messagePreviewTextField;
@property (weak) IBOutlet NSTextField *subjectTextField;
@property (weak) IBOutlet NSTextField *dateTextField;
@property (weak) IBOutlet NSButton *unseenButton;
@property (weak) IBOutlet NSButton *starButton;
@property (weak) IBOutlet SMMessageBookmarksView *bookmarksView;

@property IBOutlet NSButton *messagesCountButton;

@property IBOutlet NSImageView *attachmentImage;
@property IBOutlet NSLayoutConstraint *attachmentImageLeftContraint;
@property IBOutlet NSLayoutConstraint *attachmentImageRightContraint;
@property IBOutlet NSLayoutConstraint *attachmentImageBottomContraint;

- (void)initFields;

- (void)showContactImage;
- (void)hideContactImage;

- (void)showAttachmentImage;
- (void)hideAttachmentImage;

- (void)setMessagesCount:(NSUInteger)messagesCount;

@end
