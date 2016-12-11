//
//  SMSMAccountMailboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAbstractAccount.h"
#import "SMUserAccount.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMUserAccount.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolder.h"
#import "SMDatabase.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMFolderDesc.h"
#import "SMOpDeleteFolder.h"
#import "SMOperationExecutor.h"
#import "SMPreferencesController.h"
#import "SMMailboxViewController.h"
#import "SMAccountMailboxController.h"

#define FOLDER_LIST_UPDATE_INTERVAL_SEC 5

@implementation SMAccountMailboxController {
    MCOIMAPFetchFoldersOperation *_fetchFoldersOp;
    MCOIMAPOperation *_createFolderOp;
    MCOIMAPOperation *_renameFolderOp;
}

@synthesize selectedFolder = _selectedFolder;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        // NOP
    }
    
    return self;
}

- (void)changeFolder:(SMFolder *)folder {
    _selectedFolder = folder;
}

- (void)scheduleFolderListUpdate:(BOOL)now {
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
    __weak id weakSelf = self;
    [[_account database] loadDBFolders:^(SMDatabaseOp *op, NSArray<SMFolderDesc*> *folders) {
        SMAccountMailboxController *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [(SMAccountMailboxController*)_self->_account.mailboxController loadExistingFolders:folders];
    }];
}

- (void)updateFolders {
    SM_LOG_DEBUG(@"updating folders");

    MCOIMAPSession *session = [ (SMUserAccount*)(SMUserAccount*)_account imapSession ];
    NSAssert(session != nil, @"session is nil");

    if(_fetchFoldersOp == nil) {
        _fetchFoldersOp = [session fetchAllFoldersOperation];
    }
    
    __weak id weakSelf = self;
    [_fetchFoldersOp start:^(NSError * error, NSArray *folders) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [_self processFetchFoldersOpResult:error folders:folders];
    }];
}

- (void)processFetchFoldersOpResult:(NSError*)error folders:(NSArray*)folders {
    _fetchFoldersOp = nil;
    
    // schedule now to keep the folder list updated
    // regardless of any connectivity or server errors
    [self scheduleFolderListUpdate:NO];
    
    if(error == nil || error.code == MCOErrorNone) {
        SMAccountMailbox *mailbox = [ _account mailbox ];
        NSAssert(mailbox != nil, @"mailbox is nil");
        
        NSSet<SMFolderDesc*> *vanishedFolders;
        if([mailbox updateIMAPFolders:folders vanishedFolders:&vanishedFolders]) {
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            
            NSUInteger accountIdx = [appDelegate.accounts indexOfObject:(SMUserAccount*)_account];
            NSAssert(accountIdx != NSNotFound, @"mailbox account is not found");
            
            NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];
            
            for(SMFolderDesc *vanishedFolder in vanishedFolders) {
                [[_account database] removeDBFolder:vanishedFolder.folderName];
                [updatedLabels removeObjectForKey:vanishedFolder.folderName];
            }
            
            [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
            
            [self addFoldersToDatabase];

            [_account ensureMainLocalFoldersCreated];
        }
        
        [SMNotificationsController localNotifyFolderListUpdated:(SMUserAccount*)_account];
    }
    else {
        SM_LOG_ERROR(@"Error downloading folders structure: %@", error);
        
        [SMNotificationsController localNotifyAccountSyncError:(SMUserAccount*)_account error:error];
    }
}

- (void)loadExistingFolders:(NSArray<SMFolderDesc*>*)folderDescs {
    SMAccountMailbox *mailbox = [_account mailbox];
    NSAssert(mailbox != nil, @"mailbox is nil");

    if([mailbox loadExistingFolders:folderDescs]) {
        [_account ensureMainLocalFoldersCreated];
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        [[appDelegate appController] performSelectorOnMainThread:@selector(updateMailboxFolderListForAccount:) withObject:_account waitUntilDone:NO];
        // TODO: get rid of the deferred selector call
    }

    [self scheduleFolderListUpdate:YES];
}

- (void)addFoldersToDatabase {
    SMAccountMailbox *mailbox = [_account mailbox];
    NSAssert(mailbox != nil, @"mailbox is nil");

    for(SMFolder *folder in mailbox.mainFolders) {
        NSAssert(folder != nil, @"folder in mailbox.mainFolders is nil");
        [[_account database] addDBFolder:folder.fullName delimiter:folder.delimiter flags:folder.mcoFlags];
    }

    for(SMFolder *folder in mailbox.folders) {
        NSAssert(folder != nil, @"folder in mailbox.folders is nil");
        [[_account database] addDBFolder:folder.fullName delimiter:folder.delimiter flags:folder.mcoFlags];
    }
}

- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName {
    SMAccountMailbox *mailbox = [ _account mailbox ];
    NSAssert(mailbox != nil, @"mailbox is nil");

    MCOIMAPSession *session = [ (SMUserAccount*)_account imapSession ];
    NSAssert(session != nil, @"session is nil");

    NSString *fullFolderName = [mailbox constructFolderName:folderName parent:parentFolderName];
    if(fullFolderName == nil)
        return nil;
    
    NSAssert(_createFolderOp == nil, @"another create folder op exists");
    _createFolderOp = [session createFolderOperation:fullFolderName];

    __weak id weakSelf = self;
    [_createFolderOp start:^(NSError * error) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [_self processCreateFolderOpResults:error fullFolderName:fullFolderName];
    }];
    
    return fullFolderName;
}

- (void)processCreateFolderOpResults:(NSError*)error fullFolderName:(NSString*)fullFolderName {
    _createFolderOp = nil;
    
    if (error != nil && error.code != MCOErrorNone) {
        SM_LOG_ERROR(@"Error creating folder %@: %@", fullFolderName, error);
    }
    else {
        SM_LOG_DEBUG(@"Folder %@ created", fullFolderName);
        
        [(SMAccountMailboxController*)_account.mailboxController scheduleFolderListUpdate:YES];
    }
}

- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName {
    SM_LOG_INFO(@"Renaming folder %@ to %@", oldFolderName, newFolderName);

    if([oldFolderName isEqualToString:newFolderName])
        return;

    id<SMMailbox> mailbox = [ _account mailbox ];
    NSAssert(mailbox != nil, @"mailbox is nil");
    
    MCOIMAPSession *session = [ (SMUserAccount*)_account imapSession ];
    NSAssert(session != nil, @"session is nil");
    
    NSAssert(_renameFolderOp == nil, @"another create folder op exists");
    _renameFolderOp = [session renameFolderOperation:oldFolderName otherName:newFolderName];
    
    __weak id weakSelf = self;
    [_renameFolderOp start:^(NSError * error) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [_self processRenameFolderOpResult:error newFolderName:newFolderName oldFolderName:oldFolderName];
    }];
}

- (void)processRenameFolderOpResult:(NSError*)error newFolderName:(NSString*)newFolderName oldFolderName:(NSString*)oldFolderName {
    _renameFolderOp = nil;
    
    if (error != nil && error.code != MCOErrorNone) {
        SM_LOG_ERROR(@"Error renaming folder %@ to %@: %@", oldFolderName, newFolderName, error);
    } else {
        SM_LOG_DEBUG(@"Folder %@ renamed to %@", oldFolderName, newFolderName);
        
        [(SMAccountMailboxController*)_account.mailboxController scheduleFolderListUpdate:YES];
    }
}

- (void)deleteFolder:(NSString*)folderName {
    SMOpDeleteFolder *op = [[SMOpDeleteFolder alloc] initWithRemoteFolder:folderName operationExecutor:[(SMUserAccount*)_account operationExecutor]];
        
    SM_LOG_INFO(@"Enqueueing deleting of remote folder %@", folderName);
    
    // 1. Delete the remote folder
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    
    // 2. Remove folder from the mailbox
    [(SMAccountMailbox*)_account.mailbox removeFolder:folderName];
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
    
    // 3. Delete the serialized folder from the database
    [[_account database] removeDBFolder:folderName];
    
    // 4. Remove associated labels
    NSUInteger accountIdx = [appDelegate.accounts indexOfObject:(SMUserAccount*)_account];
    NSAssert(accountIdx != NSNotFound, @"mailbox account is not found");

    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];
    [updatedLabels removeObjectForKey:folderName];
    [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
}

- (NSUInteger)totalMessagesCount:(SMFolder*)folder {
    SMLocalFolderRegistry *localFolderRegistry = [_account localFolderRegistry];
    id<SMAbstractLocalFolder> localFolder = [localFolderRegistry getLocalFolderByName:folder.fullName];
    
    if(localFolder != nil) {
        return localFolder.totalMessagesCount;
    }
    else {
        return 0;
    }
}

- (NSUInteger)unseenMessagesCount:(SMFolder*)folder {
    SMLocalFolderRegistry *localFolderRegistry = [_account localFolderRegistry];
    id<SMAbstractLocalFolder> localFolder = [localFolderRegistry getLocalFolderByName:folder.fullName];
    
    if(localFolder != nil) {
        return localFolder.unseenMessagesCount;
    }
    else {
        return 0;
    }
}

@end
