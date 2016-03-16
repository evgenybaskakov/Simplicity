//
//  SMAppDelegate.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMSimplicityContainer.h"

@class SMAppController;
@class SMAccountDescriptor;
@class SMPreferencesController;
@class SMImageRegistry;

@interface SMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

+ (NSURL*)appDataDir;

@property SMAppController *appController;

@property (readonly) SMPreferencesController *preferencesController;
@property (readonly) SMAccountDescriptor *account; // TODO
@property (readonly) SMSimplicityContainer *model; // TODO
@property (readonly) SMImageRegistry *imageRegistry;

@property (assign) IBOutlet NSWindow *window;

@property NSUInteger currentAccount;

@end
