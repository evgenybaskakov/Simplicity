//
//  SMUnifiedMailbox.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMOutboxController.h"
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
@synthesize foldersLoaded = _foldersLoaded;
@synthesize alwaysSyncedFolders = _alwaysSyncedFolders;

- (id)init {
    self = [super init];
    
    if(self) {
        _inboxFolder = [[SMFolder alloc] initWithFullName:@"Inbox" delimiter:'/' mcoFlags:MCOIMAPFolderFlagInbox kind:SMFolderKindInbox];
        _importantFolder = [[SMFolder alloc] initWithFullName:@"Important" delimiter:'/' mcoFlags:MCOIMAPFolderFlagImportant kind:SMFolderKindImportant];
        _sentFolder = [[SMFolder alloc] initWithFullName:@"Sent" delimiter:'/' mcoFlags:MCOIMAPFolderFlagSentMail kind:SMFolderKindSent];
        _draftsFolder = [[SMFolder alloc] initWithFullName:@"Drafts" delimiter:'/' mcoFlags:MCOIMAPFolderFlagDrafts kind:SMFolderKindDrafts];
        _starredFolder = [[SMFolder alloc] initWithFullName:@"Starred" delimiter:'/' mcoFlags:MCOIMAPFolderFlagStarred kind:SMFolderKindStarred];
        _spamFolder = [[SMFolder alloc] initWithFullName:@"Spam" delimiter:'/' mcoFlags:MCOIMAPFolderFlagSpam kind:SMFolderKindSpam];
        _trashFolder = [[SMFolder alloc] initWithFullName:@"Trash" delimiter:'/' mcoFlags:MCOIMAPFolderFlagTrash kind:SMFolderKindTrash];
        _allMailFolder = [[SMFolder alloc] initWithFullName:@"All Mail" delimiter:'/' mcoFlags:MCOIMAPFolderFlagAllMail kind:SMFolderKindAllMail];
        
        _outboxFolder = [[SMFolder alloc] initWithFullName:[SMOutboxController outboxFolderName] delimiter:'/' mcoFlags:MCOIMAPFolderFlagNone kind:SMFolderKindOutbox];
        
        _mainFolders = @[_inboxFolder, _importantFolder, _outboxFolder, _sentFolder, _draftsFolder, _starredFolder, _spamFolder, _trashFolder, _allMailFolder ];

        _alwaysSyncedFolders = @[];

        _foldersLoaded = YES; // TODO
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
    for(SMFolder *f in _folders) {
        if([f.fullName isEqualToString:folderName])
            return f;
    }
    
    for(SMFolder *f in _mainFolders) {
        if([f.fullName isEqualToString:folderName])
            return f;
    }
    
    return nil;
}

- (NSString*)constructFolderName:(NSString*)folderName parent:(NSString*)parentFolderName {
    SM_FATAL(@"TODO");
    return nil;
}

@end
