//
//  SMAccountButtonViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/12/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMColorView.h"
#import "SMPreferencesController.h"
#import "SMAccountButtonViewController.h"

@implementation SMAccountButtonViewController {
    NSTrackingArea *_trackingArea;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

    ((SMColorView*)self.view).backgroundColor = [NSColor clearColor];
    
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited) owner:self userInfo:nil];
    
    [self.view addTrackingArea:_trackingArea];
}

- (void)reloadAccountInfo {
    NSString *accountImagePath = [[[[NSApplication sharedApplication] delegate] preferencesController] accountImagePath:_accountIdx];
    NSAssert(accountImagePath != nil, @"accountImagePath is nil");
    
    _accountImage.image = [[NSImage alloc] initWithContentsOfFile:accountImagePath];
    
    if([[[[NSApplication sharedApplication] delegate] preferencesController] shouldShowEmailAddressesInMailboxes]) {
        _accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] userEmail:_accountIdx];
    }
    else {
        _accountName.stringValue = [[[[NSApplication sharedApplication] delegate] preferencesController] accountName:_accountIdx];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if(_trackMouse) {
        ((SMColorView*)self.view).backgroundColor = _backgroundColor;
    }
    
    [self.view setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)theEvent {
    ((SMColorView*)self.view).backgroundColor = [NSColor clearColor];
    
    [self.view setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(NSColor*)backgroundColor {
    _backgroundColor = [backgroundColor colorWithAlphaComponent:0.2];

    ((SMColorView*)self.view).backgroundColor = [NSColor clearColor];
    
    [self.view setNeedsDisplay:YES];
}

@end
