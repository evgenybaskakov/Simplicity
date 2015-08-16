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

@implementation SMMessageWindowController {
    SMMessageThreadViewController *_messageThreadViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Delegate setup
    
    [[self window] setDelegate:self];
    
    NSView *view = [[SMFlippedView alloc] initWithFrame:[[self window] frame]];
    [[self window] setContentView:view];
    
    _messageThreadViewController = [[SMMessageThreadViewController alloc] initWithNibName:nil bundle:nil];
    NSAssert(_messageThreadViewController, @"_messageThreadViewController");
    
    NSView *messageThreadView = [_messageThreadViewController view];
    NSAssert(messageThreadView, @"messageThreadView");
    
    messageThreadView.translatesAutoresizingMaskIntoConstraints = YES;

    [view addSubview:messageThreadView];
    
    messageThreadView.frame = view.frame;
    messageThreadView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    [_messageThreadViewController setMessageThread:_currentMessageThread];
}

- (void)windowWillClose:(NSNotification *)notification {
    // TODO
}

@end
