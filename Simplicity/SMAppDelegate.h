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

#define UNIFIED_ACCOUNT_IDX -1

@interface SMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

+ (NSURL*)appDataDir;

@property SMAppController *appController;

@property (assign) IBOutlet NSWindow *window;

@property (readonly) SMPreferencesController *preferencesController;
@property (readonly) SMMessageComparators *messageComparators;
@property (readonly) SMAttachmentStorage *attachmentStorage;
@property (readonly) SMAddressBookController *addressBookController;
@property (readonly) SMImageRegistry *imageRegistry;
@property (readonly) SMUnifiedMailbox *unifiedMailbox;
@property (readonly) SMUnifiedMailboxController *unifiedMailboxController;

@property (readonly, nonatomic) NSArray<SMUserAccount*> *accounts;
@property (readonly, nonatomic) SMUserAccount *currentAccount;
@property (readonly, nonatomic) id<SMMailbox> currentMailbox;
@property (readonly, nonatomic) id<SMMailboxController> currentMailboxController;
@property (readonly, nonatomic) NSInteger currentAccountIdx;
@property (readonly, nonatomic) BOOL currentAccountInactive;
@property (readonly, nonatomic) BOOL accountsExist;

- (void)addAccount;
- (void)removeAccount:(NSUInteger)accountIdx;
- (void)setCurrentMailbox:(id<SMMailbox>)mailbox;
- (void)enableOrDisableAccountControls;

@end
