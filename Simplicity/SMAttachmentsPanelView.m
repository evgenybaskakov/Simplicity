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
#import "SMAttachmentsPanelViewController.h"
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

// Intrinsic content size

-(NSSize)intrinsicContentSize {
    NSUInteger resultingHeight = 150;
    
    if(_attachmentsPanelViewController != nil && _attachmentsPanelViewController.attachmentItems.count > 0) {
        NSAssert(self.superview != nil, @"no superview");

        const NSUInteger itemCount = _attachmentsPanelViewController.attachmentItems.count;
        const NSSize itemSize = [self itemPrototype].view.frame.size;

        SM_LOG_DEBUG(@"panel frame %g x %g, scroll view frame %g x %g", self.frame.size.width, self.frame.size.height, self.enclosingScrollView.frame.size.width, self.enclosingScrollView.frame.size.height);

        const NSUInteger rowItemCount = self.enclosingScrollView.frame.size.width / itemSize.width;
        
        if(rowItemCount > 0) {
            const NSUInteger rowCount = (itemCount / rowItemCount) + (itemCount % rowItemCount > 0? 1 : 0);
            
            resultingHeight = itemSize.height * rowCount;
        }
        else {
            resultingHeight = itemSize.height * itemCount;
        }

        SM_LOG_DEBUG(@"number of items: %lu, panel height: %lu", _attachmentsPanelViewController.attachmentItems.count, resultingHeight);
    }

    return NSMakeSize(-1, resultingHeight);
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];

    if(_attachmentsPanelViewController != nil) {
        [_attachmentsPanelViewController invalidateIntrinsicContentViewSize];
    }
}

@end
