//
//  SMAttachmentsPanelItemView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAttachmentItem.h"
#import "SMRoundedImageView.h"
#import "SMAttachmentsPanelView.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMAttachmentsPanelViewItem.h"

static const CGFloat BOX_ALPHA = 0.5;

@implementation SMAttachmentsPanelViewItem {
	NSTrackingArea *_trackingArea;
	Boolean _hasMouseOver;
    Boolean _hasPreview;
}

- (NSColor*)selectedColor {
	return [NSColor blueColor];
}

- (NSColor*)selectedColorWithMouseOver {
	return [[self unselectedWithMouseOverColor] blendedColorWithFraction:0.2 ofColor:[self selectedColor]];
}

- (NSColor*)unselectedWithMouseOverColor {
    return [NSColor blackColor];
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
    
    self.collectionView.minItemSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    self.collectionView.maxItemSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
}

- (SMAttachmentsPanelViewController*)collectionViewController {
    SMAttachmentsPanelView *collectionView = (SMAttachmentsPanelView *)self.collectionView;
    NSAssert([collectionView isKindOfClass:[SMAttachmentsPanelView class]], @"bad collection view type: %@", collectionView.class);
    
    return collectionView.attachmentsPanelViewController;
}

- (void)setPreviewImage:(NSImage *)image {
    SMRoundedImageView *imageView = (SMRoundedImageView*)self.imageView;
    
    imageView.image = image;
    imageView.frame = self.box.frame;
    imageView.imageScaling = NSImageScaleNone;
    imageView.cornerRadius = self.box.cornerRadius;
    imageView.insetsWidth = 0;

    _box.alphaValue = 0;
    
    _hasPreview = YES;
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
 
    if(selected) {
        if(_hasMouseOver) {
            _box.fillColor = [self selectedColorWithMouseOver];
            _box.alphaValue = BOX_ALPHA;
        }
        else {
            _box.fillColor = [self selectedColor];
            _box.alphaValue = BOX_ALPHA;
        }
    }
    else {
        if(_hasMouseOver) {
            _box.fillColor = [self unselectedWithMouseOverColor];
            _box.alphaValue = BOX_ALPHA;
       }
        else {
            _box.alphaValue = 0;
        }
    }
 }

- (void)mouseEntered:(NSEvent *)theEvent {
    if([self isSelected]) {
        _box.fillColor = [self selectedColorWithMouseOver];
        _box.alphaValue = BOX_ALPHA;
    }
    else {
        _box.fillColor = [self unselectedWithMouseOverColor];
        _box.alphaValue = BOX_ALPHA;
    }
	
	_hasMouseOver = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
    if([self isSelected]) {
        _box.fillColor = [self selectedColor];
        _box.alphaValue = BOX_ALPHA;
    }
    else {
        _box.alphaValue = 0;
    }
    
	_hasMouseOver = NO;
}

-(void)mouseDown:(NSEvent *)theEvent {
	[super mouseDown:theEvent];

	if([theEvent clickCount] == 2) {
		SM_LOG_DEBUG(@"double click");
		//[NSApp sendAction:@selector(collectionItemViewDoubleClick:) to:nil from:[self object]];

        SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
        [panelViewController openAttachment:self.representedObject];
	}
}

- (void)rightMouseDown:(NSEvent *)theEvent {
	[super rightMouseDown:theEvent];
	
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    
    if(self.collectionView.selectionIndexes.count > 1) {
        [theMenu addItemWithTitle:@"Open" action:@selector(openSelectedAttachments) keyEquivalent:@""];
        [theMenu addItemWithTitle:@"Save To Downloads" action:@selector(saveSelectedAttachmentsToDownloads) keyEquivalent:@""];
        [theMenu addItemWithTitle:@"Save To..." action:@selector(saveSelectedAttachments) keyEquivalent:@""];
        
        if(panelViewController.enabledEditing) {
            [theMenu addItemWithTitle:@"Remove" action:@selector(removeSelectedAttachments) keyEquivalent:@""];
        }
    }
    else {
        [theMenu addItemWithTitle:@"Open" action:@selector(openAttachment) keyEquivalent:@""];
        [theMenu addItemWithTitle:@"Save To Downloads" action:@selector(saveAttachmentToDownloads) keyEquivalent:@""];
        [theMenu addItemWithTitle:@"Save To..." action:@selector(saveAttachment) keyEquivalent:@""];
        
        if(panelViewController.enabledEditing) {
            [theMenu addItemWithTitle:@"Remove" action:@selector(removeAttachment) keyEquivalent:@""];
        }
    }

    [NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:self.view];
}

- (void)rightMouseUp:(NSEvent *)theEvent {
	[super rightMouseUp:theEvent];
}

#pragma mark Menu actions

- (void)openAttachment {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController openAttachment:self.representedObject];
}

- (void)saveAttachment {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveAttachment:self.representedObject];
}

- (void)saveAttachmentToDownloads {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveAttachmentToDownloads:self.representedObject];
}

- (void)removeAttachment {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController removeAttachment:self.representedObject];
}

- (void)openSelectedAttachments {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController openSelectedAttachments];
}

- (void)saveSelectedAttachments {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveSelectedAttachments];
}

- (void)saveSelectedAttachmentsToDownloads {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveSelectedAttachmentsToDownloads];
}

- (void)removeSelectedAttachments {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController removeSelectedAttachments];
}

@end
