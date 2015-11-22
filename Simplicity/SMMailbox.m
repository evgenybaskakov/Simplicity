//
//  SMFolderTree.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#include <CoreFoundation/CFStringEncodingExt.h>

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMFolder.h"
#import "SMFolderDesc.h"
#import "SMAppDelegate.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"

@implementation SMMailbox {
	NSMutableArray *_mainFolders;
	NSMutableOrderedSet *_favoriteFolders;
	NSMutableArray *_folders;
	NSMutableArray *_sortedFlatFolders;
}

- (id)init {
	self = [ super init ];
	
	if(self) {
		[self cleanFolders];

		_favoriteFolders = [[NSMutableOrderedSet alloc] init];
		_sortedFlatFolders = [NSMutableArray array];
	}

	return self;
}

- (void)cleanFolders {
	_rootFolder = [[SMFolder alloc] initWithName:@"ROOT" fullName:@"ROOT" delimiter:'/' flags:MCOIMAPFolderFlagNone];
	_mainFolders = [NSMutableArray array];
	_folders = [NSMutableArray array];
}

- (BOOL)loadExistingFolders:(NSArray*)existingFolders {
    if(existingFolders.count > 0) {
        SM_LOG_INFO(@"%lu existing folders found", existingFolders.count);

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
		[self addFolderToMailbox:fd.folderName delimiter:fd.delimiter flags:fd.flags];
	}

	[self updateMainFolders];
	[self updateFavoriteFolders];

    SM_LOG_DEBUG(@"number of folders %lu", _folders.count);
    
	return YES;
}

- (void)dfs:(SMFolder *)folder {
	[_folders addObject:folder];
	
    for(SMFolder *subfolder in folder.subfolders) {
		[self dfs:subfolder];
    }
}

- (void)addFolderToMailbox:(NSString*)folderFullName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
	SMFolder *curFolder = _rootFolder;
	
	NSArray *tokens = [folderFullName componentsSeparatedByString:[NSString stringWithFormat:@"%c", delimiter]];
	NSMutableString *currentFullName = [NSMutableString new];
	
	for(NSUInteger i = 0; i < [tokens count]; i++) {
		NSString *token = tokens[i];

		if(i > 0)
			[currentFullName appendFormat:@"%c", delimiter];
		
		[currentFullName appendString:token];
		
		Boolean found = NO;
		
		for(SMFolder *f in [curFolder subfolders]) {
			if([token compare:[f shortName]] == NSOrderedSame) {
				curFolder = f;
				found = YES;
				break;
			}
		}

		if(!found) {
			for(; i < [tokens count]; i++)
				curFolder = [curFolder addSubfolder:token fullName:currentFullName delimiter:delimiter flags:flags];
			
			break;
		}
	}
	
	// build flat structure

	// TODO: currently the flat structure is rebuilt on each folder addition
	//       instead, it should be constructed iteratively
	[_folders removeAllObjects];
	
	NSAssert(_rootFolder.subfolders.count > 0, @"root folder is empty");

    for(SMFolder *subfolder in _rootFolder.subfolders) {
		[self dfs:subfolder];
    }
}

- (void)updateMainFolders {
	[_mainFolders removeAllObjects];
	
	_inboxFolder = [self addFolderWithFlags:MCOIMAPFolderFlagInbox orName:@"INBOX" as:@"INBOX" setKind:SMFolderKindInbox];
	_importantFolder = [self addFolderWithFlags:MCOIMAPFolderFlagImportant orName:nil as:@"Important" setKind:SMFolderKindImportant];
	_sentFolder = [self addFolderWithFlags:MCOIMAPFolderFlagSentMail orName:nil as:@"Sent" setKind:SMFolderKindSent];
    _draftsFolder = [self addFolderWithFlags:MCOIMAPFolderFlagDrafts orName:nil as:@"Drafts" setKind:SMFolderKindDrafts];
    _starredFolder = [self addFolderWithFlags:MCOIMAPFolderFlagStarred orName:nil as:@"Starred" setKind:SMFolderKindStarred];
	_spamFolder = [self addFolderWithFlags:MCOIMAPFolderFlagSpam orName:nil as:@"Spam" setKind:SMFolderKindSpam];
	_trashFolder = [self addFolderWithFlags:MCOIMAPFolderFlagTrash orName:nil as:@"Trash" setKind:SMFolderKindTrash];
	_allMailFolder = [self addFolderWithFlags:MCOIMAPFolderFlagAllMail orName:nil as:@"All Mail" setKind:SMFolderKindAllMail];

    [_mainFolders addObject:_inboxFolder];
    [_mainFolders addObject:_importantFolder];
    [_mainFolders addObject:_sentFolder];
    [_mainFolders addObject:_draftsFolder];
    [_mainFolders addObject:_starredFolder];
    [_mainFolders addObject:_spamFolder];
    [_mainFolders addObject:_trashFolder];
    [_mainFolders addObject:_allMailFolder];
}

- (SMFolder*)addFolderWithFlags:(MCOIMAPFolderFlag)flags orName:(NSString*)name as:(NSString*)displayName setKind:(SMFolderKind)kind {
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

- (void)sortFavorites {
	[_favoriteFolders sortUsingComparator:^NSComparisonResult(SMFolder *f1, SMFolder *f2) {
		return [f1.fullName compare:f2.fullName];
	}];
}

- (void)updateFavoriteFolders {
	static Boolean firstTime = YES;
	if(firstTime) {
		// TODO: remove
		[self addFavoriteFolderWithName:@"Work/CVC/DVBS"];
		[self addFavoriteFolderWithName:@"Private/Misc"];
		[self addFavoriteFolderWithName:@"Work/Charter"];
		firstTime = NO;
	}

	for(SMFolder *folder in _folders) {
		if(folder.favorite) {
			[_favoriteFolders addObject:folder];
		} else {
			[_favoriteFolders removeObject:folder];
		}
	}

	[self sortFavorites];
}

- (void)addFavoriteFolderWithName:(NSString*)name {
	for(NSUInteger i = 0; i < _folders.count; i++) {
		SMFolder *folder = _folders[i];

		if(!folder.favorite && [folder.fullName compare:name] == NSOrderedSame) {
			folder.favorite = YES;

			[_favoriteFolders addObject:folder];

			[self sortFavorites];

			break;
		}
	}
}

- (void)removeFavoriteFolderWithName:(NSString*)name {
	for(NSUInteger i = 0; i < _folders.count; i++) {
		SMFolder *folder = _folders[i];

		if([folder.fullName compare:name] == NSOrderedSame) {
			if(folder.favorite) {
				folder.favorite = NO;
				
				[_favoriteFolders removeObject:folder];
			}

			break;
		}
	}
}

- (SMFolder*)getFolderByKind:(SMFolderKind)kind {
    // TODO: cache it
    for(SMFolder *f in _mainFolders) {
        if(f.kind == kind)
            return f;
    }
    
    return nil;
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
