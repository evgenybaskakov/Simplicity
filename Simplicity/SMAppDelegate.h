//
//  SMAppDelegate.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/31/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMUserAccount.h"

@protocol SMMailbox;
@protocol SMMailboxController;

@class SMAppController;
@class SMUserAccount;
@class SMPreferencesController;
@class SMUnifiedMailbox;
@class SMUnifiedMailboxController;
@class SMMessageComparators;
@class SMAddressBookController;
@class SMAttachmentStorage;
@class SMImageRegistry;

@interface SMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

+ (NSURL*)appDataDir;

@property SMAppController *appController;

@property (assign) IBOutlet NSWindow *window;

@property (readonly) SMPreferencesController *preferencesController;
@property (readonly) SMMessageComparators *messageComparators;
@property (readonly) SMAttachmentStorage *attachmentStorage;
@property (readonly) SMAddressBookController *addressBookController;
@property (readonly) SMImageRegistry *imageRegistry;
@property (readonly, nonatomic) SMUserAccount *currentAccount;
@property (readonly, nonatomic) NSArray<SMUserAccount*> *accounts;
@property (readonly) SMUnifiedMailbox *unifiedMailbox;
@property (readonly) NSObject<SMMailbox> *currentMailbox;
@property (readonly) NSObject<SMMailboxController> *currentMailboxController;

@property (nonatomic) NSUInteger currentAccountIdx;
@property (nonatomic) BOOL accountsExist;

- (void)addAccount;
- (void)removeAccount:(NSUInteger)accountIdx;
- (void)enableOrDisableAccountControls;

@end
