//
//  SMUnifiedMailbox.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMailbox.h"
#import "SMUnifiedMailbox.h"

@implementation SMUnifiedMailbox

@synthesize rootFolder = _rootFolder;
@synthesize inboxFolder = _inboxFolder;
@synthesize outboxFolder = _outboxFolder;
@synthesize sentFolder = _sentFolder;
@synthesize draftsFolder = _draftsFolder;
@synthesize importantFolder = _importantFolder;
@synthesize starredFolder = _starredFolder;
@synthesize spamFolder = _spamFolder;
@synthesize allMailFolder = _allMailFolder;
@synthesize trashFolder = _trashFolder;
@synthesize mainFolders = _mainFolders;
@synthesize folders = _folders;
@synthesize alwaysSyncedFolders = _alwaysSyncedFolders;
@synthesize foldersLoaded = _foldersLoaded;

- (id)init {
    self = [super init];
    
    if(self) {
        
        // Blah.
        
    }
    
    return self;
}

- (void)addMailbox:(SMMailbox*)mailbox {
    SM_FATAL(@"TODO");
}

- (void)removeMailbox:(SMMailbox*)mailbox {
    SM_FATAL(@"TODO");
}

- (void)updateMailbox:(SMMailbox*)mailbox {
    SM_FATAL(@"TODO");
}

- (SMFolder*)getFolderByName:(NSString*)folderName {
    SM_FATAL(@"TODO");
    return nil;
}

- (NSString*)constructFolderName:(NSString*)folderName parent:(NSString*)parentFolderName {
    SM_FATAL(@"TODO");
    return nil;
}

@end
