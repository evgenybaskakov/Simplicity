//
//  SMWindow.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMWindow.h"

@implementation SMWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

- (BOOL)makeFirstResponder:(nullable NSResponder *)responder {
    BOOL result = [super makeFirstResponder:responder];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    // See http://stackoverflow.com/questions/9643544/how-to-easily-close-a-nswindow-that-is-not-key?rq=1
    // Apparently everybody use this stupid way of closing a floating panel.
    [appController closeSearchMenu];

    return result;
}

@end
