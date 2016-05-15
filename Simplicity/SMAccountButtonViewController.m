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

@interface SMAccountButtonViewController ()
@property IBOutlet NSLayoutConstraint *unreadCountToAttentionButtonContraint;
@end

@implementation SMAccountButtonViewController {
    NSLayoutConstraint *_unreadCountToViewContraint;
    NSTrackingArea *_trackingArea;
    BOOL _attentionButtonShown;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.

    _unreadCountField.stringValue = @"";
    
    _unreadCountToViewContraint = [NSLayoutConstraint constraintWithItem:_unreadCountField attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:-5];
    
    _attentionButtonShown = YES;
    
    [self hideAttention];

    ((SMColorView*)self.view).backgroundColor = [NSColor clearColor];
    
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited) owner:self userInfo:nil];
    
    [self.view addTrackingArea:_trackingArea];
}

- (void)showAttention:(NSString*)attentionText {
    if(_attentionButton.toolTip != attentionText) {
        _attentionButton.toolTip = attentionText;
    }
    
    if(_attentionButtonShown) {
        return;
    }

    NSAssert(_unreadCountToAttentionButtonContraint != nil, @"_unreadCountToAttentionButtonContraint == nil");
    NSAssert(_unreadCountToViewContraint != nil, @"_unreadCountToViewContraint == nil");
    
    [self.view removeConstraint:_unreadCountToViewContraint];
    [self.view addConstraint:_unreadCountToAttentionButtonContraint];
    
    _attentionButton.hidden = NO;
    
    _attentionButtonShown = YES;
}

- (void)hideAttention {
    if(!_attentionButtonShown) {
        return;
    }
    
    NSAssert(_unreadCountToAttentionButtonContraint != nil, @"_unreadCountToAttentionButtonContraint == nil");
    NSAssert(_unreadCountToViewContraint != nil, @"_unreadCountToViewContraint == nil");
    
    [self.view removeConstraint:_unreadCountToAttentionButtonContraint];
    [self.view addConstraint:_unreadCountToViewContraint];
    
    _attentionButton.hidden = YES;
    
    _attentionButtonShown = NO;
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
