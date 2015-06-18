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

@property IBOutlet NSCollectionView *collectionView;
@property IBOutlet NSArrayController *arrayController;

@property NSMutableArray *attachmentItems;

- (void)setMessage:(SMMessage*)message;
- (void)enableEditing:(SMMessageEditorController*)messageEditorController;

@end
