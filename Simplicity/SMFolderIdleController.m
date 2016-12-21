//
//  SMFolderIdleController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/9/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "Reachability.h"

#import "SMLog.h"
#import "SMStringUtils.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMFolderUpdateController.h"
#import "SMMailbox.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMNotificationsController.h"
#import "SMUserAccount.h"
#import "SMFolderIdleController.h"

@implementation SMFolderIdleController {
    SMUserAccount __weak *_account;
    SMFolderUpdateController __weak *_updateController;
    Reachability *_imapServerReachability;
    MCOIMAPOperation *_checkAccountOp;
    MCOIMAPIdleOperation *_idleOp;
    NSInteger _idleId;
}

- (id)initWithUserAccount:(SMUserAccount*)account folder:(SMLocalFolder*)folder updateController:(SMFolderUpdateController*)updateController {
    self = [super init];
    
    if(self) {
        NSAssert(folder != nil, @"folder being watched is nil");
        NSAssert(folder.remoteFolderName != nil, @"name of the folder being watched is nil");

        _account = account;
        _watchedFolder = folder;
        _updateController = updateController;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncError:) name:@"AccountSyncError" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChangedNotification:) name:kReachabilityChangedNotification object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [_imapServerReachability stopNotifier];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)stopReachabilityMonitor {
    if(_imapServerReachability) {
        [_imapServerReachability stopNotifier];
        _imapServerReachability = nil;
    }
}

- (void)accountSyncError:(NSNotification*)notification {
    NSError *error;
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncErrorParams:notification error:&error account:&account];
    
    NSAssert(account != nil, @"account is nil");
    NSAssert(error != nil, @"error is nil");
    
    BOOL severeError;
    switch(error.code) {
        case MCOErrorTLSNotAvailable:
        case MCOErrorCertificate:
        case MCOErrorAuthentication:
        case MCOErrorGmailIMAPNotEnabled:
        case MCOErrorMobileMeMoved:
        case MCOErrorYahooUnavailable:
        case MCOErrorStartTLSNotAvailable:
        case MCOErrorNeedsConnectToWebmail:
        case MCOErrorAuthenticationRequired:
        case MCOErrorInvalidAccount:
        case MCOErrorCompression:
        case MCOErrorGmailApplicationSpecificPasswordRequired:
        case MCOErrorServerDate:
        case MCOErrorNoValidServerFound:
            severeError = YES;
            break;
            
        default:
            severeError = NO;
            break;
    }
    
    if(severeError) {
        NSString *errorDesc = [SMStringUtils trimString:error.localizedDescription];
        if(errorDesc.length == 0) {
            errorDesc = @"Unknown server error occurred.";
        }
        else if([errorDesc characterAtIndex:errorDesc.length-1] != '.') {
            errorDesc = [errorDesc stringByAppendingString:@"."];
        }
        
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Dismiss"];
        [alert addButtonWithTitle:@"Properties"];
        [alert setMessageText:[NSString stringWithFormat:@"There was a problem accessing your accout \"%@\"", account.accountName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ Error code %ld.\n\nPlease choose either to open account preferences, or dismiss this message.", errorDesc, error.code]];
        [alert setAlertStyle:NSCriticalAlertStyle];
        
        if([alert runModal] == NSAlertSecondButtonReturn) {
            // Exit the alert modal loop first.
            // Easiest way is to dispatch the request to the main thread queue.
            dispatch_async(dispatch_get_main_queue(), ^{
                SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
                [[appDelegate appController] showPreferencesWindowAction:YES accountName:account.accountName];
            });
        }
    }
    else {
        if(_imapServerReachability) {
            [_imapServerReachability stopNotifier];
        }
        
        NSString *imapServer = _account.imapSession.hostname;
        
        _imapServerReachability = [Reachability reachabilityWithHostname:imapServer];
        
        SMFolderIdleController *__weak weakSelf = self;
        _imapServerReachability.reachableBlock = ^(Reachability *reachability) {
            SM_LOG_INFO(@"reachability triggers");
            
            SMFolderIdleController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if(_self->_imapServerReachability != reachability) {
                    SM_LOG_WARNING(@"stale reachability object for IMAP server %@", imapServer);
                    return;
                }
                
                [_self imapServerReachable];
            });
        };
        
        SM_LOG_INFO(@"stopping IDLE for folder %@", _watchedFolder.remoteFolderName);
        
        [self stopIdle];
        
        [_imapServerReachability startNotifier];
    }
}

- (void)reachabilityChangedNotification:(NSNotification*)notification {
    SM_LOG_INFO(@"server reachability changed: %@", notification);
}

- (void)imapServerReachable {
    [_imapServerReachability stopNotifier];
    _imapServerReachability = nil;
    
    SM_LOG_INFO(@"IMAP server %@ is now reachable", _account.imapSession.hostname);
    
    if(_checkAccountOp) {
        [_checkAccountOp cancel];
        _checkAccountOp = nil;
    }
    
    MCOIMAPOperation *checkAccountOp = [_account.imapSession checkAccountOperation];
    
    __weak id weakSelf = self;
    [checkAccountOp start:^(NSError *error) {
        SMFolderIdleController *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        if(_self->_checkAccountOp != checkAccountOp) {
            SM_LOG_WARNING(@"stale _checkAccountOp object for IMAP server %@", _self->_account.imapSession.hostname);
            return;
        }
        
        _self->_checkAccountOp = nil;
        
        if(error == nil || error.code == MCOErrorNone) {
            [SMNotificationsController localNotifyAccountSyncSuccess:_self->_account];
        }
    }];
    
    _checkAccountOp = checkAccountOp;
    
    if(!_account.imapServerAvailable) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        
        NSUInteger accountIdx = [appDelegate accountIndex:_account];
        [appDelegate reconnectAccount:accountIdx];
    }
    else {
        [_updateController scheduleFolderUpdate:NO];
    }
}

- (void)startIdle {
    if(![_account idleEnabled:_watchedFolder.kind]) {
        SM_LOG_INFO(@"IDLE is disabled");
        return;
    }
    
    if(_idleOp != nil) {
        // This happens when the control message check is finished
        // as we just enabled the idle operation.
        SM_LOG_INFO(@"idle operation is already running for folder '%@', id %lu", _watchedFolder.remoteFolderName, _idleId);
        return;
    }
    
    NSUInteger idleId = ++_idleId;
    SM_LOG_INFO(@"new IDLE operation is running for folder '%@', id %lu", _watchedFolder.remoteFolderName, idleId);
    
    SMFolderIdleController __weak *weakSelf = self;
    void (^opBlock)(NSError *) = ^(NSError *error) {
        SMFolderIdleController *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        if(idleId != _self->_idleId) {
            SM_LOG_INFO(@"stale idle operation dismissed, id %lu", idleId);
            return;
        }
        
        if(error && error.code != MCOErrorNone) {
            SM_LOG_ERROR(@"IDLE operation error for folder '%@', id %lu: %@", _self->_watchedFolder.remoteFolderName, _self->_idleId, error);
        }
        else {
            SM_LOG_INFO(@"IDLE operation triggers for '%@', id %lu", _self->_watchedFolder.remoteFolderName, _self->_idleId);
        }

        SMLocalFolder *folder = _self->_watchedFolder;
        
        _self->_idleOp = nil;
        
        // In any case, just sync the messages.
        // Any connectivity errors will be handled alongside.
        [folder startLocalFolderSync];
    };
    
    _idleOp = [_account.imapSession idleOperationWithFolder:_watchedFolder.remoteFolderName lastKnownUID:0];
    [_idleOp start:opBlock];
    
    // After the idle op is started, we must check if there are any changes happened.
    // If we don't then there's a time gap between the last sync and the idle start,
    // i.e. we're at risk to miss something.
    [_watchedFolder startLocalFolderSync];
}

- (void)stopIdle {
    if(![_account idleEnabled:_watchedFolder.kind]) {
        SM_LOG_INFO(@"IDLE is disabled");
        return;
    }
    
    if(_idleOp != nil) {
        SM_LOG_INFO(@"cancelling IDLE operation for folder '%@', id %lu", _watchedFolder.remoteFolderName, _idleId);
        
        [_idleOp cancel];
        
        _idleOp = nil;
    }
}

@end
