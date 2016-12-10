//
//  SMMessageListUpdater.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/12/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAbstractAccount.h"
#import "SMUserAccount.h"
#import "SMNotificationsController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadAccountProxy.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMAccountMailbox.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMLocalFolderRegistry.h"
#import "SMUnifiedLocalFolder.h"
#import "SMAbstractLocalFolder.h"
#import "SMSearchLocalFolder.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"

@implementation SMMessageListController {
    id<SMAbstractLocalFolder> _currentFolder;
    id<SMAbstractLocalFolder> _prevNonSearchFolder;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesInLocalFolderUpdated:) name:@"MessagesUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    }

    return self;
}

- (id<SMAbstractLocalFolder>)currentLocalFolder {
    return _currentFolder;
}

- (void)changeFolderInternal:(NSString*)folderName remoteFolder:(NSString*)remoteFolderName syncWithRemoteFolder:(BOOL)syncWithRemoteFolder {
    SM_LOG_DEBUG(@"new folder '%@'", folderName);

    if(_currentFolder != nil && _currentFolder.kind != SMFolderKindSearch) {
        _prevNonSearchFolder = _currentFolder;
    }

    [_currentFolder stopLocalFolderSync:YES];

    // Stop "always synced" folders sync, as we want the new folder to updated ASAP
    for(SMFolder *folder in [(SMAccountMailbox*)_account.mailbox alwaysSyncedFolders]) {
        SMLocalFolder *localFolder = (SMLocalFolder*)[[_account localFolderRegistry] getLocalFolderByName:folder.fullName];
        [localFolder stopLocalFolderSync:YES];
    }
    
    // Cancel automatic updates of this folder
    [_account cancelScheduledMessagesUpdate];

    // Create the new local folder if necessary
    if(folderName != nil) {
        id<SMAbstractLocalFolder> localFolder = [[_account localFolderRegistry] getLocalFolderByName:folderName];
        
        if(localFolder == nil) {
            SMFolder *folder = [[_account mailbox] getFolderByName:folderName];
            SMFolderKind kind = (folder != nil? folder.kind : SMFolderKindRegular);

            localFolder = [[_account localFolderRegistry] createLocalFolder:folderName remoteFolder:remoteFolderName kind:kind syncWithRemoteFolder:syncWithRemoteFolder];
        }
        
        _currentFolder = localFolder;
    } else {
        _currentFolder = nil;
    }
}

- (void)changeFolder:(NSString*)folder clearSearch:(BOOL)clearSearch {
    if([_currentFolder.localName isEqualToString:folder]) {
        return;
    }

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    if(clearSearch) {
        [appController clearSearch:NO cancelFocus:YES];
    }
    
    [self changeFolderInternal:folder remoteFolder:folder syncWithRemoteFolder:YES];
    [self startMessagesUpdate];
    
    if(_account == appDelegate.currentAccount || appDelegate.currentAccountIsUnified) {
        BOOL preserveSelection = NO;
        [[appController messageListViewController] reloadMessageList:preserveSelection updateScrollPosition:YES];
    }
}

- (void)changeToPrevFolder {
    if(_prevNonSearchFolder != nil) {
        [self changeFolder:_prevNonSearchFolder.localName clearSearch:NO];

        _prevNonSearchFolder = nil;
    }
}

- (void)clearCurrentFolderSelection {
    if(_currentFolder == nil)
        return;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController clearSearch:NO cancelFocus:YES];
    
    [self changeFolderInternal:nil remoteFolder:nil syncWithRemoteFolder:NO];
    
    if(_account == appDelegate.currentAccount || appDelegate.currentAccountIsUnified) {
        BOOL preserveSelection = NO;
        [[appController messageListViewController] reloadMessageList:preserveSelection];
    }
}

- (void)loadSearchResults:(MCOIndexSet*)searchResults remoteFolderToSearch:(NSString*)remoteFolderNameToSearch searchResultsLocalFolder:(NSString*)searchResultsLocalFolder changeFolder:(BOOL)changeFolder {
    
    if(changeFolder) {
        [self changeFolderInternal:searchResultsLocalFolder remoteFolder:remoteFolderNameToSearch syncWithRemoteFolder:NO];
    }
    
    // TODO: This is wrong. The message list controller shouldn't be dependent on the
    //       actual nature of the local folder. It should just show whateher the local folder has.
    //       So when searching within the Unified Account, each account's message list controller
    //       shouldn't change to the search local folder. See issue #103.
    NSAssert([(NSObject*)_currentFolder isKindOfClass:[SMSearchLocalFolder class]], @"local folder %@ is not an instance of search folder", _currentFolder.localName);
    
    BOOL updateSearchResults = (changeFolder? NO : YES);
    [(SMSearchLocalFolder*)_currentFolder loadSelectedMessages:searchResults updateResults:updateSearchResults];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    if(_account == appDelegate.currentAccount || appDelegate.currentAccountIsUnified) {
        BOOL preserveSelection = NO;
        [[appController messageListViewController] reloadMessageList:preserveSelection];
    }
}

- (void)startMessagesUpdate {
    SM_LOG_DEBUG(@"updating message list");
    
    [_currentFolder startLocalFolderSync];
}

- (void)messagesInLocalFolderUpdated:(NSNotification *)notification {
    SMLocalFolder *localFolder = [[notification userInfo] objectForKey:@"LocalFolderInstance"];
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if(_currentFolder == localFolder || (appDelegate.currentAccountIsUnified && _account.unified && [(SMUnifiedLocalFolder*)_currentFolder hasLocalFolderAttached:localFolder])) {
        NSNumber *resultValue = [[notification userInfo] objectForKey:@"UpdateResult"];
        SMMessageStorageUpdateResult updateResult = [resultValue unsignedIntegerValue];
        
        if(updateResult != SMMesssageStorageUpdateResultNone) {
            if(_account == appDelegate.currentAccount || appDelegate.currentAccountIsUnified) {
                SMAppController *appController = [appDelegate appController];
                
                [[appController messageListViewController] reloadMessageList:YES updateScrollPosition:YES];
                [[appController messageThreadViewController] updateMessageThread];
            }
        }
    }
}

// Fetching message data

- (void)fetchMessageInlineAttachments:(SMMessage*)message messageThread:(SMMessageThread*)messageThread {
    if(_account.unified) {
        [messageThread.account fetchMessageInlineAttachments:message];
    }
    else {
        [_account fetchMessageInlineAttachments:message];
    }
}

- (void)fetchMessageBodyUrgentlyWithUID:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName messageThread:(SMMessageThread*)messageThread {
    SM_LOG_DEBUG(@"msg uid %u, remote folder %@, threadId %llu", uid, remoteFolderName, messageThread.threadId);

    if(_account.unified) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate.messageThreadAccountProxy fetchMessageBodyUrgently:messageThread uid:uid messageId:messageId messageDate:messageDate remoteFolder:remoteFolderName];
    }
    else {
        [_currentFolder fetchMessageBodyUrgentlyWithUID:uid messageId:messageId messageDate:messageDate remoteFolder:remoteFolderName threadId:messageThread.threadId];
    }
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    BOOL updateNow;
    BOOL hasUpdates;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder updateNow:&updateNow hasUpdates:&hasUpdates account:&account];

    // The unified account is never related to message updates.
    // So always ignore it.
    if(_account == account && _currentFolder == localFolder) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        SMAppController *appController = [appDelegate appController];
        
        NSAssert(!_account.unified, @"Cannot process fetched messages in the unified account");
        
        [[appController messageListViewController] messageHeadersSyncFinished:hasUpdates updateScrollPosition:YES];
        
        // Keep certain folders always synced.
        // Go through the "always synced" folders and update them.
// TODO: fix this mess
//        for(SMFolder *folder in [(SMAccountMailbox*)_account.mailbox alwaysSyncedFolders]) {
//            SMLocalFolder *localFolder = (SMLocalFolder*)[[_account localFolderRegistry] getLocalFolderByName:folder.fullName];
//            
//            if(localFolder != _currentFolder) {
//                [localFolder startLocalFolderSync];
//            }
//        }
        
        // Schedule message update only we are being asked to.
        [_account scheduleMessageListUpdate:updateNow];
    }
}

- (BOOL)localFolderIsCurrent:(SMLocalFolder*)localFolder {
    BOOL result = NO;

    if(_currentFolder != nil) {
        if(_account.unified) {
            if([(SMUnifiedLocalFolder*)_currentFolder hasLocalFolderAttached:localFolder]) {
                result = YES;
            }
        }
        else if(_currentFolder == localFolder) {
            result = YES;
        }
    }
    
    return result;
}

@end
