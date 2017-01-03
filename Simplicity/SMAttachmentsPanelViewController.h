//
//  SMAttachmentsPanelViewContoller.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMBox2;
@class SMMessage;
@class SMMessageEditorController;
@class SMAttachmentsPanelView;
@class SMAttachmentItem;

@interface SMAttachmentsPanelViewController : NSViewController<NSCollectionViewDelegate, NSDraggingSource, NSDraggingDestination>

@property IBOutlet SMBox2 *outerBox;
@property IBOutlet NSButton *togglePanelButton;
@property IBOutlet SMAttachmentsPanelView *collectionView;
@property IBOutlet NSArrayController *arrayController;

@property (readonly) NSMutableArray *attachmentItems;
@property (readonly) NSUInteger collapsedHeight;
@property (readonly) NSUInteger uncollapsedHeight;
@property (readonly) BOOL enabledEditing;

- (IBAction)togglePanelAction:(id)sender;

- (void)setMessage:(SMMessage*)message;
- (void)setToggleTarget:(id)toggleTarget;
- (void)enableEditing:(SMMessageEditorController*)messageEditorController;
- (void)addFileAttachments:(NSArray*)files;
- (void)addMCOAttachments:(NSArray*)attachments;

- (void)openAttachment:(SMAttachmentItem*)attachmentItem;
- (void)saveAttachment:(SMAttachmentItem*)attachmentItem;
- (void)saveAttachmentToDownloads:(SMAttachmentItem*)attachmentItem;
- (NSString*)saveAttachment:(SMAttachmentItem*)attachmentItem toPath:(NSString*)folderPath;
- (void)removeAttachment:(SMAttachmentItem*)attachmentItem;

- (void)openSelectedAttachments;
- (void)saveSelectedAttachments;
- (void)saveSelectedAttachmentsToDownloads;
- (void)saveAllAttachments;
- (void)saveAllAttachmentsToDownloads;
- (void)removeSelectedAttachments;
- (void)unselectAllAttachments;

- (void)invalidateIntrinsicContentViewSize;
- (NSSize)intrinsicContentViewSize;

@end
