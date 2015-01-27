//
//  SMAttachmentsPanelItemView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelItemViewController.h"

@implementation SMAttachmentsPanelItemViewController {
	NSTrackingArea *_trackingArea;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		// nothing yet
	}
	
	return self;
}

- (void)viewDidLoad {
	_trackingArea = [[NSTrackingArea alloc] initWithRect:[_box frame] options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
	
	[[self view] addTrackingArea:_trackingArea];
}

- (void)setSelected:(BOOL)flag {
	[super setSelected: flag];
 
	NSAssert(_box != nil, @"no box set");

	NSColor *fillColor = flag? [NSColor selectedControlColor] : [NSColor controlBackgroundColor];
 
	[_box setFillColor:fillColor];
}

-(void)mouseDown:(NSEvent *)theEvent {
	[super mouseDown:theEvent];

	if([theEvent clickCount] == 2) {
		NSLog(@"%s: double click", __func__);
		//[NSApp sendAction:@selector(collectionItemViewDoubleClick:) to:nil from:[self object]];
		
		SMAttachmentItem *attachmentItem = [self representedObject];

		NSLog(@"%s: attachment item %@", __func__, attachmentItem.fileName);

		NSString *filePath = [NSString pathWithComponents:@[@"/tmp", attachmentItem.fileName]];

		// TODO: write to the message attachments folder
		// TODO: write only if not written yet (compare checksum?)
		// TODO: do it asynchronously
		NSError *writeError = nil;
		if(![attachmentItem.fileData writeToFile:filePath options:NSDataWritingAtomic error:&writeError]) {
			NSLog(@"%s: Could not write file %@: %@", __func__, filePath, writeError);
			return; // TODO: error popup?
		}
		
		NSLog(@"%s: File written: %@", __func__, filePath);

		[[NSWorkspace sharedWorkspace] openFile:filePath];
	}
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSLog(@"%s", __func__);
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSLog(@"%s", __func__);
}

- (void)updateTrackingAreas {
	NSLog(@"%s", __func__);
}

@end
