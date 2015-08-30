//
//  SMAttachmentsPanelViewContoller.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessage;
@class SMMessageEditorController;

@interface SMAttachmentsPanelViewController : NSViewController<NSCollectionViewDelegate, NSDraggingSource, NSDraggingDestination>

@property IBOutlet NSButton *togglePanelButton;
@property IBOutlet NSCollectionView *collectionView;
@property IBOutlet NSArrayController *arrayController;

@property (readonly) NSMutableArray *attachmentItems;
@property (readonly) NSUInteger collapsedHeight;
@property (readonly) NSUInteger uncollapsedHeight;

- (IBAction)togglePanelAction:(id)sender;

- (void)setMessage:(SMMessage*)message;
- (void)setToggleTarget:(id)toggleTarget;
- (void)enableEditing:(SMMessageEditorController*)messageEditorController;
- (void)addFiles:(NSArray*)files;

@end
