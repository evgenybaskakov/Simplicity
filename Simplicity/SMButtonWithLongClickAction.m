//
//  SMButtonWithMenu.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMButtonWithLongClickAction.h"

@implementation SMButtonWithLongClickAction {
    NSTimer *_timer;
    BOOL _timerFired;
}

- (void)mouseDown:(NSEvent *)theEvent {
    [self setHighlighted:YES];
    [self setNeedsDisplay:YES];

    _timerFired = NO;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(sendLongClickAction:) userInfo:nil repeats:NO];
    
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSEventTrackingRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)mouseUp:(NSEvent *)theEvent {
    [self setHighlighted:NO];
    [self setNeedsDisplay:YES];
    
    [_timer invalidate];
    _timer = nil;
    
    if(!_timerFired) {
        [NSApp sendAction:[self action] to:[self target] from:self];
    }
    
    _timerFired = NO;
}

- (void)sendLongClickAction:(NSTimer*)timer {
    if(!_timer) {
        return;
    }
    
    _timer = nil;
    _timerFired = YES;

    if(_longClickAction) {
        [NSApp sendAction:_longClickAction to:[self target] from:self];
    }
    
    [self setState:NSOnState];
}

@end
