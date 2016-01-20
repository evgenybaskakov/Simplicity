//
//  SMSuggestionsMenuRowView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMSectionMenuViewController.h"
#import "SMSectionMenuItemView.h"

@implementation SMSectionMenuItemView {
    NSTrackingArea *_trackingArea;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

#pragma mark Tracking area

- (void)ensureTrackingArea {
    if(_trackingArea == nil) {
        _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    [self ensureTrackingArea];
    
    if(![[self trackingAreas] containsObject:_trackingArea]) {
        [self addTrackingArea:_trackingArea];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [_parentMenuViewController selectItem:self.textField.tag];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [_parentMenuViewController unselectItem:self.textField.tag];
}

@end
