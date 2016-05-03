//
//  SMUnifiedMailboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUnifiedMailboxController.h"

@implementation SMUnifiedMailboxController

@synthesize selectedFolder = _selectedFolder;

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

- (NSUInteger)unseenMessagesCount:(NSString*)folderName {
    SM_LOG_WARNING(@"TODO");
    return 0;
}

- (NSUInteger)totalMessagesCount:(NSString*)folderName {
    SM_LOG_WARNING(@"TODO");
    return 0;
}

@end
