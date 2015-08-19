//
//  SMAttachmentsPanelView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMImageRegistry.h"
#import "SMAttachmentsPanelView.h"

@implementation SMAttachmentsPanelView

- (void)drawRect:(NSRect)dirtyRect {
    SM_LOG_DEBUG(@"???");

	[super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)dragPromisedFilesOfTypes:(NSArray *)typeArray
						fromRect:(NSRect)aRect
						  source:(id)sourceObject
					   slideBack:(BOOL)slideBack
						   event:(NSEvent *)theEvent
{
	SM_LOG_DEBUG(@"???");
	return YES;
}

//- (void)setDraggingSourceOperationMask:(NSDragOperation)dragOperationMask forLocal:(BOOL)localDestination {
//  SM_LOG_DEBUG(@"???");
//}

- (NSImage *)draggingImageForItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event offset:(NSPointPointer)dragImageOffset {
	SM_LOG_DEBUG(@"???");

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	NSImage *dragImage = appDelegate.imageRegistry.attachmentDocumentImage;
	return dragImage; // TODO: scale to a size
}

@end
