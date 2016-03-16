//
//  SMMessageListUpdater.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/12/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMNotificationsController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMSimplicityContainer.h"
#import "SMPreferencesController.h"
#import "SMMailbox.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolder.h"
#import "SMSearchFolder.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"

@interface SMMessageListController()
- (void)startMessagesUpdate;
@end

@implementation SMMessageListController {
    __weak SMSimplicityContainer *_model;
    SMLocalFolder *_currentFolder;
    SMLocalFolder *_prevNonSearchFolder;
    MCOIMAPFolderInfoOperation *_folderInfoOp;
}

- (id)initWithModel:(SMSimplicityContainer*)model {
    self = [ super init ];
    
    if(self) {
        _model = model;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    }

    return self;
}

- (SMLocalFolder*)currentLocalFolder {
    return _currentFolder;
}

- (void)changeFolderInternal:(NSString*)folderName remoteFolder:(NSString*)remoteFolderName syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    SM_LOG_DEBUG(@"new folder '%@'", folderName);

    if(_currentFolder != nil && ![_currentFolder isKindOfClass:[SMSearchFolder class]]) {
        _prevNonSearchFolder = _currentFolder;
    }

    [_currentFolder stopMessagesLoading];
    
    [_folderInfoOp cancel];
    _folderInfoOp = nil;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel scheduled message list update

    if(folderName != nil) {
        SMLocalFolder *localFolder = [[_model localFolderRegistry] getLocalFolder:folderName];
        
        if(localFolder == nil) {
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

            SMFolder *folder = [[[appDelegate model] mailbox] getFolderByName:folderName];
            SMFolderKind kind = (folder != nil? folder.kind : SMFolderKindRegular);

            localFolder = [[_model localFolderRegistry] createLocalFolder:folderName remoteFolder:remoteFolderName kind:kind syncWithRemoteFolder:syncWithRemoteFolder];
        }
        
        _currentFolder = localFolder;
    } else {
        _currentFolder = nil;
    }
}

- (void)changeFolder:(NSString*)folder {
    [self changeFolder:folder clearSearch:YES];
}

- (void)changeFolder:(NSString*)folder clearSearch:(BOOL)clearSearch {
    if([_currentFolder.localName isEqualToString:folder]) {
        return;
    }

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    if(clearSearch) {
        [appController clearSearch];
    }
    
    [self changeFolderInternal:folder remoteFolder:folder syncWithRemoteFolder:YES];
    [self startMessagesUpdate];
    
    Boolean preserveSelection = NO;
    [[appController messageListViewController] reloadMessageList:preserveSelection updateScrollPosition:YES];
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
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController clearSearch];
    
    [self changeFolderInternal:nil remoteFolder:nil syncWithRemoteFolder:NO];
    
    Boolean preserveSelection = NO;
    [[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)startMessagesUpdate {
    SM_LOG_DEBUG(@"updating message list");

    [_currentFolder startLocalFolderSync];
}

- (void)cancelMessageListUpdate {
    [_currentFolder stopMessagesLoading];
}

- (void)loadSearchResults:(MCOIndexSet*)searchResults remoteFolderToSearch:(NSString*)remoteFolderNameToSearch searchResultsLocalFolder:(NSString*)searchResultsLocalFolder updateResults:(BOOL)updateResults {
    
    if(!updateResults) {
        [self changeFolderInternal:searchResultsLocalFolder remoteFolder:remoteFolderNameToSearch syncWithRemoteFolder:NO];
    }
    
    NSAssert([_currentFolder isKindOfClass:[SMSearchFolder class]], @"local folder %@ is not an instance of search folder", _currentFolder.localName);
    [(SMSearchFolder*)_currentFolder loadSelectedMessages:searchResults updateResults:updateResults];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    Boolean preserveSelection = NO;
    [[appController messageListViewController] reloadMessageList:preserveSelection];
}

- (void)updateMessageList {
    //TODO:
    //if(updateResult == SMMesssageStorageUpdateResultNone) {
        // no updates, so no need to reload the message list
    //  return;
    //}
    
    // TODO: special case for flags changed in some cells only
    
    SM_LOG_DEBUG(@"some messages updated, the list will be reloaded");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];

    [[appController messageListViewController] reloadMessageList:YES updateScrollPosition:YES];
}

- (void)updateMessageThreadView {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [[appController messageThreadViewController] updateMessageThread];
}

- (void)cancelScheduledMessageListUpdate {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startMessagesUpdate) object:nil];
}

- (NSUInteger)messageListUpdateIntervalSec {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger updateIntervalSec = [[appDelegate preferencesController] messageCheckPeriodSec];
    
    if(updateIntervalSec == 0) {
        // TODO: handle 0 ("auto") value in a more sophisticated way
        updateIntervalSec = 60;
    }
    
    return updateIntervalSec;
}

- (void)scheduleMessageListUpdate:(Boolean)now {
    [self cancelScheduledMessageListUpdate];
    
    NSTimeInterval delay_sec = now? 0 : [self messageListUpdateIntervalSec];
    
    SM_LOG_DEBUG(@"scheduling message list update after %lu sec", (unsigned long)delay_sec);

    [self performSelector:@selector(startMessagesUpdate) withObject:nil afterDelay:delay_sec];
}

- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
    SM_LOG_DEBUG(@"msg uid %u, remote folder %@, threadId %llu", uid, remoteFolderName, threadId);

    [_currentFolder fetchMessageBodyUrgently:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId];
}

- (void)messagesUpdated:(NSNotification *)notification {
    NSString *localFolder = [[notification userInfo] objectForKey:@"LocalFolderName"];

    if([_currentFolder.localName isEqualToString:localFolder]) {
        NSNumber *resultValue = [[notification userInfo] objectForKey:@"UpdateResult"];
        SMMessageStorageUpdateResult updateResult = [resultValue unsignedIntegerValue];
        
        if(updateResult != SMMesssageStorageUpdateResultNone) {
            NSString *localFolder = [[notification userInfo] objectForKey:@"LocalFolderName"];

            if([_currentFolder.localName isEqualToString:localFolder]) {
                [self updateMessageList];
                [self updateMessageThreadView];
            }
        }
    }
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
    NSString *localFolder;
    BOOL hasUpdates;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder hasUpdates:&hasUpdates account:&account];

    if([_currentFolder.localName isEqualToString:localFolder]) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMAppController *appController = [appDelegate appController];
        
        [[appController messageListViewController] messageHeadersSyncFinished:hasUpdates updateScrollPosition:YES];
    }
}

@end
