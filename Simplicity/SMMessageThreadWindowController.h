//
//  SMMessageThreadWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SMAbstractLocalFolder;

@class SMMessageThread;

@interface SMMessageThreadWindowController : NSWindowController<NSWindowDelegate>

@property (readonly) SMMessageThreadViewController *messageThreadViewController;

@property id<SMAbstractLocalFolder> localFolder;
@property SMMessageThread *messageThread;

@end
