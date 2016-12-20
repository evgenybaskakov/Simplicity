//
//  SMFolderUpdateController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMUserAccount.h"
#import "SMLocalFolder.h"
#import "SMFolderIdleController.h"
#import "SMFolderUpdateController.h"

static const NSUInteger AUTO_MESSAGE_CHECK_PERIOD_SEC = 60;

@implementation SMFolderUpdateController {
    SMUserAccount __weak *_account;
    SMFolderIdleController *_idleController;
}

- (id)initWithUserAccount:(SMUserAccount*)account folder:(SMLocalFolder*)folder {
    self = [super init];
    
    if(self) {
        _account = account;
        _watchedFolder = folder;
        _idleController = [[SMFolderIdleController alloc] initWithUserAccount:account folder:folder updateController:self];
    }
    
    return self;
}

- (void)dealloc {
    [self cancelScheduledFolderUpdate];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)scheduleFolderUpdate:(BOOL)now {
    if(!_account.imapServerAvailable) {
        SM_LOG_INFO(@"IMAP server not available, postponing message list update (account '%@')", _account.accountName);
        return;
    }
    
    if(now) {
        [_watchedFolder startLocalFolderSync];
    }
    else {
        if([_account idleEnabled:_watchedFolder.kind] && _idleController != nil) {
            [_idleController startIdle];
        }
        else {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startFolderUpdate) object:nil];
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            NSUInteger updateIntervalSec = [[appDelegate preferencesController] messageCheckPeriodSec];
            
            if(updateIntervalSec == 0) {
                updateIntervalSec = AUTO_MESSAGE_CHECK_PERIOD_SEC;
            }
            
            SM_LOG_DEBUG(@"scheduling message list update after %lu sec (account '%@')", updateIntervalSec, _account.accountName);
            
            [self performSelector:@selector(startFolderUpdate) withObject:nil afterDelay:updateIntervalSec];
        }
    }
}

- (void)cancelScheduledFolderUpdate {
    if([_account idleEnabled:_watchedFolder.kind] && _idleController != nil) {
        SM_LOG_INFO(@"stopping IDLE for folder %@", _watchedFolder.remoteFolderName);
        
        [_idleController stopIdle];
    }
    else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startFolderUpdate) object:nil];
    }
}

- (void)startFolderUpdate {
    [_watchedFolder startLocalFolderSync];
}

@end
