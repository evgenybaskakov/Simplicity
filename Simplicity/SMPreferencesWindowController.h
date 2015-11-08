//
//  SMPreferencesWindowController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/30/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMPreferencesWindowController : NSWindowController<NSWindowDelegate>

@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSToolbar *preferencesToolbar;
@property (weak) IBOutlet NSView *preferencesView;

- (void)reloadAccounts;
- (void)showAccount:(NSString*)accountName;

@end
