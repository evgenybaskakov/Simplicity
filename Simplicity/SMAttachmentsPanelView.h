//
//  SMAttachmentsPanelView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMAttachmentsPanelViewController;

@interface SMAttachmentsPanelView : NSCollectionView

@property __weak SMAttachmentsPanelViewController *attachmentsPanelViewController;

@end
