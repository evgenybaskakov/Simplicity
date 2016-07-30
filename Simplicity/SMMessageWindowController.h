//
//  SMMessageWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessageThread;

@interface SMMessageWindowController : NSWindowController<NSWindowDelegate>

@property (readonly) SMMessageThreadViewController *messageThreadViewController;

@property SMMessageThread *currentMessageThread;

@end
