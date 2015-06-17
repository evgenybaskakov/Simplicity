//
//  SMAttachmentsPanelViewContoller.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMAttachmentsPanelViewController : NSViewController<NSCollectionViewDelegate, NSDraggingSource, NSDraggingDestination>

@property IBOutlet NSCollectionView *collectionView;
@property IBOutlet NSArrayController *arrayController;

@property NSMutableArray *attachmentItems;

@end
