//
//  SMAttachmentsPanelView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMImageRegistry.h"
#import "SMAttachmentsPanelView.h"

@implementation SMAttachmentsPanelView

- (void)drawRect:(NSRect)dirtyRect {
//	NSLog(@"%s", __func__);

	[super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)dragPromisedFilesOfTypes:(NSArray *)typeArray
						fromRect:(NSRect)aRect
						  source:(id)sourceObject
					   slideBack:(BOOL)slideBack
						   event:(NSEvent *)theEvent
{
	NSLog(@"%s", __func__);
	return YES;
}

//- (void)setDraggingSourceOperationMask:(NSDragOperation)dragOperationMask forLocal:(BOOL)localDestination {
//	NSLog(@"%s", __func__);
//}

- (NSImage *)draggingImageForItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event offset:(NSPointPointer)dragImageOffset {
	NSLog(@"%s", __func__);

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSImage *dragImage = appDelegate.imageRegistry.attachmentDocumentImage;
	return dragImage; // TODO: scale to a size
}

@end
