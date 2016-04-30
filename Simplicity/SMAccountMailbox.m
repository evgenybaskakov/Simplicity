//
//  SMAccountMailbox.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#include <CoreFoundation/CFStringEncodingExt.h>

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMFolder.h"
#import "SMFolderDesc.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMOutboxController.h"
#import "SMAccountMailbox.h"

@implementation SMAccountMailbox {
    NSMutableArray<SMFolder*> *_mainFolders;
    NSMutableArray<SMFolder*> *_folders;
    NSMutableArray<SMFolderDesc*> *_sortedFlatFolders;
}

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

- (id)initWithUserAccount:(SMUserAccount *)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        [self cleanFolders];
        
        _sortedFlatFolders = [NSMutableArray array];
    }
    
    return self;
}

- (void)cleanFolders {
    _rootFolder = [[SMFolder alloc] initWithFullName:@"ROOT" delimiter:'/' flags:MCOIMAPFolderFlagNone];
    _mainFolders = [NSMutableArray array];
    _folders = [NSMutableArray array];
}

- (BOOL)loadExistingFolders:(NSArray*)existingFolders {
    if(existingFolders.count > 0) {
        SM_LOG_INFO(@"%lu existing folders found", existingFolders.count);
        
        _foldersLoaded = YES;
        
        [self updateFlatFolders:[NSMutableArray arrayWithArray:existingFolders] vanishedFolders:nil];
        return TRUE;
    }
    else {
        SM_LOG_INFO(@"no existing folders found");
        return FALSE;
    }
}

- (Boolean)updateIMAPFolders:(NSArray *)imapFolders vanishedFolders:(NSMutableArray*)vanishedFolders {
    NSAssert(imapFolders.count > 0, @"No IMAP folders provided");
    
    NSMutableArray *flatFolders = [NSMutableArray arrayWithCapacity:imapFolders.count];
    for(NSUInteger i = 0; i < imapFolders.count; i++) {
        MCOIMAPFolder *folder = imapFolders[i];
        NSString *path = folder.path;
        NSData *pathData = [path dataUsingEncoding:NSUTF8StringEncoding];
        NSString *pathUtf8 = (__bridge NSString *)CFStringCreateWithBytes(NULL, [pathData bytes], [pathData length], kCFStringEncodingUTF7_IMAP, YES);
        
        [flatFolders addObject:[[SMFolderDesc alloc] initWithFolderName:pathUtf8 delimiter:folder.delimiter flags:folder.flags]];
    }
    
    _foldersLoaded = YES;
    
    return [self updateFlatFolders:flatFolders vanishedFolders:vanishedFolders];
}

- (Boolean)updateFlatFolders:(NSMutableArray *)flatFolders vanishedFolders:(NSMutableArray*)vanishedFolders {
    NSAssert(flatFolders.count > 0, @"No folders provided");
    
    [flatFolders sortUsingComparator:^NSComparisonResult(SMFolderDesc *fd1, SMFolderDesc *fd2) {
        return [fd1.folderName compare:fd2.folderName];
    }];
    
    if(flatFolders.count == _sortedFlatFolders.count) {
        NSUInteger i = 0;
        for(; i < flatFolders.count; i++) {
            SMFolderDesc *fd1 = flatFolders[i];
            SMFolderDesc *fd2 = _sortedFlatFolders[i];
            
            if(![fd1.folderName isEqualToString:fd2.folderName] || fd1.delimiter != fd2.delimiter || fd1.flags != fd2.flags)
                break;
        }
        
        if(i == flatFolders.count) {
            SM_LOG_DEBUG(@"folders didn't change");
            return NO;
        }
    }
    
    if(vanishedFolders != nil) {
        NSUInteger i = 0, j = 0;
        
        // compare the new and old folder lists, filtering out vanished elements
        while(i < flatFolders.count && j < _sortedFlatFolders.count) {
            SMFolderDesc *fd1 = flatFolders[i];
            SMFolderDesc *fd2 = _sortedFlatFolders[j];
            
            NSComparisonResult compareResult = [fd1.folderName compare:fd2.folderName];
            
            if(compareResult == NSOrderedAscending) {
                i++;
            }
            else if(compareResult == NSOrderedDescending) {
                [vanishedFolders addObject:fd2];
                
                j++;
            }
            else {
                i++;
                j++;
            }
        }
        
        // store the rest of the vanished folders
        while(j < _sortedFlatFolders.count) {
            SMFolderDesc *fd2 = _sortedFlatFolders[j++];
            
            [vanishedFolders addObject:fd2];
        }
    }
    
    _sortedFlatFolders = flatFolders;
    
    [self cleanFolders];
    
    for(SMFolderDesc *fd in _sortedFlatFolders) {
        SMFolder *folder = [[SMFolder alloc] initWithFullName:fd.folderName delimiter:fd.delimiter flags:fd.flags];
        
        [_folders addObject:folder];
    }
    
    [self updateMainFolders];
    
    SM_LOG_DEBUG(@"number of folders %lu", _folders.count);
    
    return YES;
}

- (void)dfs:(SMFolder *)folder {
    [_folders addObject:folder];
}

- (void)updateMainFolders {
    [_mainFolders removeAllObjects];
    
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
}

- (SMFolder*)filterOutFolder:(MCOIMAPFolderFlag)flags orName:(NSString*)name as:(NSString*)displayName setKind:(SMFolderKind)kind {
    for(NSUInteger i = 0; i < _folders.count; i++) {
        SMFolder *folder = _folders[i];
        
        if((folder.flags & flags) || (name != nil && [folder.fullName compare:name] == NSOrderedSame)) {
            folder.displayName = displayName;
            folder.kind = kind;
            
            [_folders removeObjectAtIndex:i];
            
            return folder;
        }
    }
    
    return nil;
}

- (void)removeFolder:(NSString*)folderName {
    for(NSUInteger i = 0; i < _mainFolders.count; i++) {
        NSAssert(![_mainFolders[i].fullName isEqualToString:folderName], @"cannot remove main folder %@", folderName);
    }
    
    for(NSUInteger i = 0; i < _folders.count; i++) {
        SMFolder *folder = _folders[i];
        
        if([folder.fullName isEqualToString:folderName]) {
            [_folders removeObjectAtIndex:i];
            break;
        }
    }
    
    for(NSUInteger i = 0; i < _sortedFlatFolders.count; i++) {
        SMFolderDesc *folderDesc = _sortedFlatFolders[i];
        
        if([folderDesc.folderName isEqualToString:folderName]) {
            [_sortedFlatFolders removeObjectAtIndex:i];
            break;
        }
    }
}

- (NSArray*)alwaysSyncedFolders {
    return @[_inboxFolder, _draftsFolder];
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
    if(folderName == nil || folderName.length == 0) {
        SM_LOG_DEBUG(@"no label name specified");
        return nil;
    }
    
    if(parentFolderName != nil) {
        SMFolder *parentFolder = [self getFolderByName:parentFolderName];
        NSAssert(parentFolder != nil, @"parentFolder (name %@) is nil", parentFolderName);
        
        return [parentFolderName stringByAppendingFormat:@"%c%@", parentFolder.delimiter, folderName];
    } else {
        return folderName;
    }
}

@end
