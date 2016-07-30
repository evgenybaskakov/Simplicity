//
//  SMMessageWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFlippedView.h"
#import "SMMessageThread.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageWindowController.h"

@implementation SMMessageWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Delegate setup
    
    [[self window] setDelegate:self];
    
    NSView *view = [[SMFlippedView alloc] initWithFrame:[[self window] frame]];
    view.translatesAutoresizingMaskIntoConstraints = YES;
    [[self window] setContentView:view];
    
    _messageThreadViewController = [[SMMessageThreadViewController alloc] initWithNibName:nil bundle:nil];
    NSAssert(_messageThreadViewController, @"_messageThreadViewController");
    
    NSView *messageThreadView = [_messageThreadViewController view];
    NSAssert(messageThreadView, @"messageThreadView");
    
    messageThreadView.translatesAutoresizingMaskIntoConstraints = YES;

    [view addSubview:messageThreadView];
    
    messageThreadView.frame = view.frame;
    messageThreadView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    [_messageThreadViewController setMessageThread:_currentMessageThread selectedThreadsCount:1];
}

- (void)windowWillClose:(NSNotification *)notification {
    [_messageThreadViewController messageThreadViewWillClose];
}

@end
