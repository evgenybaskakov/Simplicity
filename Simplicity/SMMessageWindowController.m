//
//  SMMessageWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFlippedView.h"
#import "SMMessageThread.h"
#import "SMMessageThreadInfoViewController.h"
#import "SMMessageWindowController.h"

@implementation SMMessageWindowController {
    SMMessageThreadInfoViewController *_messageThreadInfoViewController;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Delegate setup
    
    [[self window] setDelegate:self];
    
    // View setup
    
    NSView *view = [[SMFlippedView alloc] initWithFrame:[[self window] frame]];
    [[self window] setContentView:view];
    
    // Editor setup
    
    _messageThreadInfoViewController = [[SMMessageThreadInfoViewController alloc] init];
    
    NSAssert(_currentMessageThread != nil, @"_currentMessageThread is not set");
    [_messageThreadInfoViewController setMessageThread:_currentMessageThread];

    NSView *infoView = [_messageThreadInfoViewController view];
    NSAssert(infoView != nil, @"no info view");
    
    infoView.translatesAutoresizingMaskIntoConstraints = YES;

    [view addSubview:infoView];

    infoView.frame = NSMakeRect(-1, 0, view.frame.size.width+2, [SMMessageThreadInfoViewController infoHeaderHeight]);
    infoView.autoresizingMask = NSViewWidthSizable;
}

- (void)windowWillClose:(NSNotification *)notification {
    // TODO
}

@end
