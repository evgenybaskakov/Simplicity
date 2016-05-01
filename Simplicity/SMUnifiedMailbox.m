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
@synthesize foldersLoaded = _foldersLoaded;

- (id)init {
    self = [super init];
    
    if(self) {
/*
        _inboxFolder = [self filterOutFolder:MCOIMAPFolderFlagInbox orName:@"INBOX" as:@"Inbox" setKind:SMFolderKindInbox];
        _importantFolder = [self filterOutFolder:MCOIMAPFolderFlagImportant orName:nil as:@"Important" setKind:SMFolderKindImportant];
        _sentFolder = [self filterOutFolder:MCOIMAPFolderFlagSentMail orName:nil as:@"Sent" setKind:SMFolderKindSent];
        _draftsFolder = [self filterOutFolder:MCOIMAPFolderFlagDrafts orName:nil as:@"Drafts" setKind:SMFolderKindDrafts];
        _starredFolder = [self filterOutFolder:MCOIMAPFolderFlagStarred orName:nil as:@"Starred" setKind:SMFolderKindStarred];
        _spamFolder = [self filterOutFolder:MCOIMAPFolderFlagSpam orName:nil as:@"Spam" setKind:SMFolderKindSpam];
        _trashFolder = [self filterOutFolder:MCOIMAPFolderFlagTrash orName:nil as:@"Trash" setKind:SMFolderKindTrash];
        _allMailFolder = [self filterOutFolder:MCOIMAPFolderFlagAllMail orName:nil as:@"All Mail" setKind:SMFolderKindAllMail];
        
        NSString *outboxFolderName = [SMOutboxController outboxFolderName];
        
        _outboxFolder = [self filterOutFolder:MCOIMAPFolderFlagNone orName:outboxFolderName as:outboxFolderName setKind:SMFolderKindOutbox];
        if(_outboxFolder == nil) {
            _outboxFolder = [[SMFolder alloc] initWithFullName:outboxFolderName delimiter:'/' flags:MCOIMAPFolderFlagNone];
            _outboxFolder.kind = SMFolderKindOutbox;
        }
        
        [_mainFolders addObject:_inboxFolder];
        [_mainFolders addObject:_importantFolder];
        [_mainFolders addObject:_outboxFolder];
        [_mainFolders addObject:_sentFolder];
        [_mainFolders addObject:_draftsFolder];
        [_mainFolders addObject:_starredFolder];
        [_mainFolders addObject:_spamFolder];
        [_mainFolders addObject:_trashFolder];
        [_mainFolders addObject:_allMailFolder];
*/

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
    SM_FATAL(@"TODO");
    return nil;
}

- (NSString*)constructFolderName:(NSString*)folderName parent:(NSString*)parentFolderName {
    SM_FATAL(@"TODO");
    return nil;
}

@end
