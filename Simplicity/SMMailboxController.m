//
//  SMMailboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMSimplicityContainer.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolder.h"
#import "SMDatabase.h"
#import "SMMailbox.h"
#import "SMFolderDesc.h"
#import "SMOpDeleteFolder.h"
#import "SMOperationExecutor.h"
#import "SMPreferencesController.h"
#import "SMMailboxViewController.h"
#import "SMMailboxController.h"

#define FOLDER_LIST_UPDATE_INTERVAL_SEC 5

@implementation SMMailboxController {
    __weak SMSimplicityContainer *_model;
    MCOIMAPFetchFoldersOperation *_fetchFoldersOp;
    MCOIMAPOperation *_createFolderOp;
    MCOIMAPOperation *_renameFolderOp;
}

- (id)initWithModel:(SMSimplicityContainer*)model {
    self = [ super init ];
    
    if(self) {
        _model = model;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesSyncedInFolder:) name:@"MessageHeadersSyncFinished" object:nil];
    }
    
    return self;
}

- (void)scheduleFolderListUpdate:(Boolean)now {
    SM_LOG_DEBUG(@"scheduling folder update after %u sec", FOLDER_LIST_UPDATE_INTERVAL_SEC);

    [self stopFolderListUpdate];

    if(now) {
        [self updateFolders];
    }
    else {
        [self performSelector:@selector(updateFolders) withObject:nil afterDelay:FOLDER_LIST_UPDATE_INTERVAL_SEC];
    }
}

- (void)stopFolderListUpdate {
    [_fetchFoldersOp cancel];
    _fetchFoldersOp = nil;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateFolders) object:nil];
}

- (void)initFolders {
    SM_LOG_DEBUG(@"initializing folders");

    // TODO: use the resulting dbOp
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] database] loadDBFolders:^(NSArray *folders) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMMailboxController *mailboxController = [[appDelegate model] mailboxController];
        
        [mailboxController loadExistingFolders:folders];
    }];
}

- (void)updateFolders {
    SM_LOG_DEBUG(@"updating folders");

    MCOIMAPSession *session = [ _model imapSession ];
    NSAssert(session != nil, @"session is nil");

    if(_fetchFoldersOp == nil) {
        _fetchFoldersOp = [session fetchAllFoldersOperation];
    }
    
    [_fetchFoldersOp start:^(NSError * error, NSArray *folders) {
        _fetchFoldersOp = nil;
        
        // schedule now to keep the folder list updated
        // regardless of any connectivity or server errors
        [self scheduleFolderListUpdate:NO];
        
        if(error == nil || error.code == MCOErrorNone) {
            SMMailbox *mailbox = [ _model mailbox ];
            NSAssert(mailbox != nil, @"mailbox is nil");

            NSMutableArray *vanishedFolders = [NSMutableArray array];
            if([mailbox updateIMAPFolders:folders vanishedFolders:vanishedFolders]) {
                SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

                NSUInteger accountIdx = appDelegate.currentAccount;
                NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];

                for(SMFolderDesc *vanishedFolder in vanishedFolders) {
                    [[[appDelegate model] database] removeDBFolder:vanishedFolder.folderName];
                    [updatedLabels removeObjectForKey:vanishedFolder.folderName];
                }
                
                [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
                
                [self addFoldersToDatabase];
                [self ensureMainLocalFoldersCreated];
            }
        }
        else {
            SM_LOG_ERROR(@"Error downloading folders structure: %@", error);
        }
        
        [SMNotificationsController localNotifyFolderListUpdated];
    }];
}

- (void)ensureMainLocalFoldersCreated {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate model] localFolderRegistry];
    SMMailbox *mailbox = [[appDelegate model] mailbox];
    
    for(SMFolder *folder in mailbox.mainFolders) {
        if([localFolderRegistry getLocalFolder:folder.fullName] == nil) {
            if(folder.kind == SMFolderKindOutbox) {
                // TODO: workaround for possible "Outbox" folder name collision
                [localFolderRegistry createLocalFolder:folder.fullName remoteFolder:nil kind:folder.kind syncWithRemoteFolder:NO];
            }
            else {
                [localFolderRegistry createLocalFolder:folder.fullName remoteFolder:folder.fullName kind:folder.kind syncWithRemoteFolder:YES];
            }
        }
    }
}

- (void)loadExistingFolders:(NSArray*)folderDescs {
    SMMailbox *mailbox = [_model mailbox];
    NSAssert(mailbox != nil, @"mailbox is nil");

    if([mailbox loadExistingFolders:folderDescs]) {
        [self ensureMainLocalFoldersCreated];
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[appDelegate appController] performSelectorOnMainThread:@selector(updateMailboxFolderList) withObject:nil waitUntilDone:NO];
    }

    [self scheduleFolderListUpdate:YES];
}

- (void)addFoldersToDatabase {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    SMMailbox *mailbox = [_model mailbox];
    NSAssert(mailbox != nil, @"mailbox is nil");

    for(SMFolder *folder in mailbox.mainFolders) {
        NSAssert(folder != nil, @"folder in mailbox.mainFolders is nil");
        [[[appDelegate model] database] addDBFolder:folder.fullName delimiter:folder.delimiter flags:folder.flags];
    }

    for(SMFolder *folder in mailbox.folders) {
        NSAssert(folder != nil, @"folder in mailbox.folders is nil");
        [[[appDelegate model] database] addDBFolder:folder.fullName delimiter:folder.delimiter flags:folder.flags];
    }
}

- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName {
    SMMailbox *mailbox = [ _model mailbox ];
    NSAssert(mailbox != nil, @"mailbox is nil");

    MCOIMAPSession *session = [ _model imapSession ];
    NSAssert(session != nil, @"session is nil");

    NSString *fullFolderName = [mailbox constructFolderName:folderName parent:parentFolderName];
    if(fullFolderName == nil)
        return nil;
    
    NSAssert(_createFolderOp == nil, @"another create folder op exists");
    _createFolderOp = [session createFolderOperation:fullFolderName];

    [_createFolderOp start:^(NSError * error) {
        _createFolderOp = nil;
        
        if (error != nil && [error code] != MCOErrorNone) {
            SM_LOG_ERROR(@"Error creating folder %@: %@", fullFolderName, error);
        } else {
            SM_LOG_DEBUG(@"Folder %@ created", fullFolderName);

            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate model] mailboxController] scheduleFolderListUpdate:YES];
        }
    }];
    
    return fullFolderName;
}

- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName {
    SM_LOG_INFO(@"Renaming folder %@ to %@", oldFolderName, newFolderName);

    if([oldFolderName isEqualToString:newFolderName])
        return;

    SMMailbox *mailbox = [ _model mailbox ];
    NSAssert(mailbox != nil, @"mailbox is nil");
    
    MCOIMAPSession *session = [ _model imapSession ];
    NSAssert(session != nil, @"session is nil");
    
    NSAssert(_renameFolderOp == nil, @"another create folder op exists");
    _renameFolderOp = [session renameFolderOperation:oldFolderName otherName:newFolderName];
    
    [_renameFolderOp start:^(NSError * error) {
        _renameFolderOp = nil;

        if (error != nil && [error code] != MCOErrorNone) {
            SM_LOG_ERROR(@"Error renaming folder %@ to %@: %@", oldFolderName, newFolderName, error);
        } else {
            SM_LOG_DEBUG(@"Folder %@ renamed to %@", oldFolderName, newFolderName);

            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate model] mailboxController] scheduleFolderListUpdate:YES];
        }
    }];
}

- (void)deleteFolder:(NSString*)folderName {
    SMOpDeleteFolder *op = [[SMOpDeleteFolder alloc] initWithRemoteFolder:folderName];
        
    SM_LOG_INFO(@"Enqueueing deleting of remote folder %@", folderName);
    
    // 1. Delete the remote folder
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
    
    // 2. Remove folder from the mailbox
    [[[appDelegate model] mailbox] removeFolder:folderName];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
    
    // 3. Delete the serialized folder from the database
    [[[appDelegate model] database] removeDBFolder:folderName];
    
    // 4. Remove associated labels
    NSUInteger accountIdx = appDelegate.currentAccount;
    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];
    [updatedLabels removeObjectForKey:folderName];
    [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
}

- (NSUInteger)totalMessagesCount:(NSString*)folderName {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate model] localFolderRegistry];
    SMLocalFolder *localFolder = [localFolderRegistry getLocalFolder:folderName];
    
    if(localFolder != nil) {
        return localFolder.totalMessagesCount;
    }
    else {
        return 0;
    }
}

- (NSUInteger)unseenMessagesCount:(NSString*)folderName {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate model] localFolderRegistry];
    SMLocalFolder *localFolder = [localFolderRegistry getLocalFolder:folderName];
    
    if(localFolder != nil) {
        return localFolder.unseenMessagesCount;
    }
    else {
        return 0;
    }
}

- (void)messagesSyncedInFolder:(NSNotification*)notifcation {
    //
    // Keep the inbox folder alway synced.
    //
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *inboxFolder = [[[appDelegate model] mailbox] inboxFolder];
    SMLocalFolder *inboxLocalFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:inboxFolder.fullName];
    
    if(![[[notifcation userInfo] objectForKey:@"LocalFolderName"] isEqualToString:inboxLocalFolder.localName]) {
        [inboxLocalFolder startLocalFolderSync];
    }
}

@end
