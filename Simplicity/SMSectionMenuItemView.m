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

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    if(_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
    }
    
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [_parentMenuViewController selectItem:self.textField.tag];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [_parentMenuViewController unselectItem:self.textField.tag];
}

@end
