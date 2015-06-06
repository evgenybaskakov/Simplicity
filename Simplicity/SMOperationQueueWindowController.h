//
//  SMOperationQueueWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/6/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMOperationQueueWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic) IBOutlet NSView *operationsView;

@end
