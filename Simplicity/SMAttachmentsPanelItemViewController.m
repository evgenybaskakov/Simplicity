//
//  SMAttachmentsPanelItemView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelItemViewController.h"

@implementation SMAttachmentsPanelItemViewController {
	NSTrackingArea *_trackingArea;
	Boolean _hasMouseOver;
}

- (NSColor*)selectedColor {
	return [NSColor selectedControlColor];
}

- (NSColor*)unselectedColor {
	return [NSColor windowBackgroundColor];
}

- (NSColor*)selectedColorWithMouseOver {
	return [[NSColor grayColor] blendedColorWithFraction:0.5 ofColor:[self selectedColor]];
}

- (NSColor*)unselectedWithMouseOverColor {
	return [NSColor grayColor];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		// nothing yet
	}
	
	return self;
}

- (void)viewDidLoad {
	_trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited) owner:self userInfo:nil];
	
	[_box addTrackingArea:_trackingArea];
}

- (void)setSelected:(BOOL)flag {
	[super setSelected:flag];
 
	NSAssert(_box != nil, @"no box set");

	NSColor *fillColor = flag? (_hasMouseOver? [self selectedColorWithMouseOver] : [self selectedColor]) : (_hasMouseOver? [self unselectedWithMouseOverColor] : [self unselectedColor]);
 
	[_box setFillColor:fillColor];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSColor *fillColor = [self isSelected]? [self selectedColorWithMouseOver] : [self unselectedWithMouseOverColor];
 
	[_box setFillColor:fillColor];
	
	_hasMouseOver = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSColor *fillColor = [self isSelected]? [self selectedColor] : [self unselectedColor];
 
	[_box setFillColor:fillColor];
	
	_hasMouseOver = NO;
}

-(void)mouseDown:(NSEvent *)theEvent {
	[super mouseDown:theEvent];

	if([theEvent clickCount] == 2) {
		SM_LOG_DEBUG(@"double click");
		//[NSApp sendAction:@selector(collectionItemViewDoubleClick:) to:nil from:[self object]];

		[self openAttachment];
	}
}

- (void)rightMouseDown:(NSEvent *)theEvent {
	[super rightMouseDown:theEvent];
	
	NSView *view = [self view];

	NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
	
	[theMenu insertItemWithTitle:@"Open Attachment" action:@selector(openAttachment) keyEquivalent:@"" atIndex:0];
	[theMenu insertItemWithTitle:@"Save To Downloads" action:@selector(saveAttachmentToDownloads) keyEquivalent:@"" atIndex:1];
	[theMenu insertItemWithTitle:@"Save To..." action:@selector(saveAttachment) keyEquivalent:@"" atIndex:2];

	[NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:view];
}

- (void)rightMouseUp:(NSEvent *)theEvent {
	[super rightMouseUp:theEvent];
}

- (void)openAttachment {
	NSString *filePath = [self saveAttachmentToPath:@"/tmp"];

	if(filePath == nil) {
		SM_LOG_DEBUG(@"cannot open attachment");
		return; // TODO: error popup?
	}
	
	[[NSWorkspace sharedWorkspace] openFile:filePath];
}

- (void)saveAttachment {
	SMAttachmentItem *attachmentItem = [self representedObject];

	NSSavePanel *savePanel = [NSSavePanel savePanel];

	// TODO: get the downloads folder from the user preferences
	// TODO: use the last used directory
	[savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
	
	// TODO: use a full-sized file panel
	[savePanel beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow] completionHandler:^(NSInteger result){
		if(result == NSFileHandlingPanelOKButton) {
			[savePanel orderOut:self];
			
			NSURL *targetFileUrl = [savePanel URL];
			if(![attachmentItem writeAttachmentTo:[targetFileUrl baseURL] withFileName:[targetFileUrl relativeString]]) {
				return; // TODO: error popup
			}
			
			[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[targetFileUrl]];
		}
	}];
}

- (void)saveAttachmentToDownloads {
	// TODO: get the downloads folder from the user preferences

	NSString *filePath = [self saveAttachmentToPath:NSHomeDirectory()];
	
	if(filePath == nil) {
		return; // TODO: error popup
	}
	
	NSURL *fileUrl = [NSURL fileURLWithPath:filePath];

	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileUrl]];
}

- (NSString*)saveAttachmentToPath:(NSString*)folderPath {
	SMAttachmentItem *attachmentItem = [self representedObject];
	
	NSString *filePath = [NSString pathWithComponents:@[folderPath, attachmentItem.fileName]];
	
	if(![attachmentItem writeAttachmentTo:[NSURL fileURLWithPath:filePath]]) {
		return nil; // TODO: error popup
	}
	
	return filePath;
}

@end
