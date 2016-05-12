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
#import "SMLocalFolderRegistry.h"
#import "SMAbstractLocalFolder.h"
#import "SMUnifiedMailboxController.h"

@implementation SMUnifiedMailboxController

@synthesize selectedFolder = _selectedFolder;

- (void)initFolders {
    // TODO
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
