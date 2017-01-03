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

static const CGFloat SELECTION_TRANSPARENCY = 0.3;

@interface SMAttachmentsPanelViewItem ()
@property (weak) IBOutlet SMRoundedImageView *previewImageView;
@end

@implementation SMAttachmentsPanelViewItem {
    NSTrackingArea *_trackingArea;
    BOOL _hasMouseOver;
    BOOL _hasPreview;
}

- (NSColor*)unselectedColor {
    return [[NSColor whiteColor] colorWithAlphaComponent:0];
}

- (NSColor*)selectedColor {
    return [[NSColor selectedTextBackgroundColor] colorWithAlphaComponent:SELECTION_TRANSPARENCY];
}

- (NSColor*)selectedColorWithMouseOver {
    return [[self unselectedWithMouseOverColor] blendedColorWithFraction:0.5 ofColor:[self selectedColor]];
}

- (NSColor*)unselectedWithMouseOverColor {
    return [[NSColor blackColor] colorWithAlphaComponent:SELECTION_TRANSPARENCY];
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

    _previewImageView.imageScaling = NSImageScaleNone;
    _previewImageView.cornerRadius = self.box.cornerRadius;
    _previewImageView.insetsWidth = 0;
    _previewImageView.nonOriginalBehavior = YES;
}

- (SMAttachmentsPanelViewController*)collectionViewController {
    SMAttachmentsPanelView *collectionView = (SMAttachmentsPanelView *)self.collectionView;
    NSAssert([collectionView isKindOfClass:[SMAttachmentsPanelView class]], @"bad collection view type: %@", collectionView.class);
    
    return collectionView.attachmentsPanelViewController;
}

- (void)setPreviewImage:(NSImage*)image {
    _previewImageView.image = image;
    
    self.textField.textColor = [NSColor whiteColor];
    self.textField.hidden = YES;
    self.imageView.hidden = YES;

    _hasPreview = YES;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
 
    if(selected) {
        if(_hasMouseOver) {
            _box.fillColor = [self selectedColorWithMouseOver];
        }
        else {
            _box.fillColor = [self selectedColor];
        }
    }
    else {
        if(_hasMouseOver) {
            _box.fillColor = [self unselectedWithMouseOverColor];
       }
        else {
            _box.fillColor = [self unselectedColor];
        }
    }
 }

- (void)mouseEntered:(NSEvent *)theEvent {
    if([self isSelected]) {
        _box.fillColor = [self selectedColorWithMouseOver];
    }
    else {
        _box.fillColor = [self unselectedWithMouseOverColor];
    }

    if(_hasPreview) {
        self.textField.hidden = NO;
    }
    else {
        self.textField.textColor = [NSColor whiteColor];
    }

    _hasMouseOver = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
    if([self isSelected]) {
        _box.fillColor = [self selectedColor];
    }
    else {
        _box.fillColor = [self unselectedColor];
    }
    
    if(_hasPreview) {
        self.textField.hidden = YES;
    }
    else {
        self.textField.textColor = [NSColor blackColor];
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
