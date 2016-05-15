//
//  SMUnifiedMailboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMailbox.h"
#import "SMLocalFolderRegistry.h"
#import "SMAbstractLocalFolder.h"
#import "SMUnifiedMailboxController.h"

@implementation SMUnifiedMailboxController

@synthesize selectedFolder = _selectedFolder;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        // nothing yet
    }
    
    return self;
}

- (void)initFolders {
    SMLocalFolderRegistry *localFolderRegistry = [_account localFolderRegistry];
    SMUnifiedMailbox *mailbox = (SMUnifiedMailbox*)[_account mailbox];
    
    for(SMFolder *folder in mailbox.mainFolders) {
        if([localFolderRegistry getLocalFolderByName:folder.fullName] == nil) {
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

- (void)changeFolder:(SMFolder *)folder {
    _selectedFolder = folder;
}

- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName {
    SM_FATAL(@"Unified mailbox can't do this (folderName %@, parentFolderName %@)", folderName, parentFolderName);
    return 0;
}

- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName {
    SM_FATAL(@"Unified mailbox can't do this (oldFolderName %@, newFolderName %@)", oldFolderName, newFolderName);
}

- (void)deleteFolder:(NSString*)folderName {
    SM_FATAL(@"Unified mailbox can't do this (folderName %@)", folderName);
}

- (NSUInteger)totalMessagesCount:(SMFolder*)folder {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate unifiedAccount] localFolderRegistry];
    id<SMAbstractLocalFolder> localFolder = [localFolderRegistry getLocalFolderByKind:folder.kind];
    
    if(localFolder == nil) {
        localFolder = [localFolderRegistry getLocalFolderByName:folder.fullName];
    }
    
    if(localFolder != nil) {
        return localFolder.totalMessagesCount;
    }
    else {
        return 0;
    }
}

- (NSUInteger)unseenMessagesCount:(SMFolder*)folder {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolderRegistry *localFolderRegistry = [[appDelegate unifiedAccount] localFolderRegistry];
    id<SMAbstractLocalFolder> localFolder = [localFolderRegistry getLocalFolderByKind:folder.kind];
    
    if(localFolder == nil) {
        localFolder = [localFolderRegistry getLocalFolderByName:folder.fullName];
    }
    
    if(localFolder != nil) {
        return localFolder.unseenMessagesCount;
    }
    else {
        return 0;
    }
}

@end
