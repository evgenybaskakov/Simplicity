//
//  SMAppDelegate.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMessageListController.h"
#import "SMImageRegistry.h"
#import "SMAppController.h"
#import "SMAppDelegate.h"

@implementation SMAppDelegate

- (id)init {
	self = [ super init ];
	if(self) {
		_imageRegistry = [ SMImageRegistry new ];
		_model = [ SMSimplicityContainer new ];
	}
	
	SM_LOG_DEBUG(@"app delegate initialized");
	
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	_window.titleVisibility = NSWindowTitleHidden;

	[[_model mailboxController] scheduleFolderListUpdate:YES];
}

+ (NSURL*)appDataDir {
	NSURL* appSupportDir = nil;
	NSArray* appSupportDirs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	
	if([appSupportDirs count] > 0) {
		appSupportDir = (NSURL*)[appSupportDirs objectAtIndex:0];
	} else {
		SM_LOG_DEBUG(@"cannot get path to app dir");
		
		appSupportDir = [NSURL fileURLWithPath:@"~/Library/Application Support/" isDirectory:YES];
	}
	
	return [appSupportDir URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
}

@end
