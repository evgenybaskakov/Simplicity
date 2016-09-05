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
@class SMUnifiedAccount;
@class SMUnifiedMailbox;
@class SMUnifiedMailboxController;
@class SMRemoteImageLoadController;
@class SMMessageComparators;
@class SMAddressBookController;
@class SMMessageThreadAccountProxy;
@class SMImageRegistry;

#define UNIFIED_ACCOUNT_IDX -1

@interface SMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

+ (NSURL*)appDataDir;

@property SMAppController *appController;

@property (assign) IBOutlet NSWindow *window;

@property (readonly) SMPreferencesController *preferencesController;
@property (readonly) SMMessageComparators *messageComparators;
@property (readonly) SMAddressBookController *addressBookController;
@property (readonly) SMRemoteImageLoadController *remoteImageLoadController;
@property (readonly) SMImageRegistry *imageRegistry;
@property (readonly) SMMessageThreadAccountProxy *messageThreadAccountProxy;
@property (readonly) SMUnifiedAccount *unifiedAccount;

@property (readonly, nonatomic) NSArray<SMUserAccount*> *accounts;
@property (readonly, nonatomic) id<SMAbstractAccount> currentAccount;
@property (readonly, nonatomic) id<SMMailbox> currentMailbox;
@property (readonly, nonatomic) id<SMMailboxController> currentMailboxController;
@property (readonly, nonatomic) NSInteger currentAccountIdx;
@property (readonly, nonatomic) BOOL currentAccountIsUnified;
@property (readonly, nonatomic) BOOL accountsExist;

+ (void)restartApplication;

- (void)addAccount;
- (void)removeAccount:(NSUInteger)accountIdx;
- (void)reloadAccount:(NSUInteger)accountIdx;
- (void)setCurrentAccount:(id<SMAbstractAccount>)account;
- (void)enableOrDisableAccountControls;

@end
