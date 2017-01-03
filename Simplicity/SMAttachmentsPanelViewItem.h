//
//  SMAttachmentsPanelItemView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMAttachmentsPanelViewItem : NSCollectionViewItem

@property (weak) IBOutlet NSBox *box;

- (void)setPreviewImage:(NSImage*)image;

@end
