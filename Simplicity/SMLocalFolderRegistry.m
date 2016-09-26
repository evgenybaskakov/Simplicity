//
//  SMLocalFolderRegistry.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAbstractAccount.h"
#import "SMUserAccount.h"
#import "SMMessageListController.h"
#import "SMFolder.h"
#import "SMAbstractLocalFolder.h"
#import "SMUnifiedLocalFolder.h"
#import "SMUnifiedAccount.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMSearchLocalFolder.h"

@interface FolderEntry : NSObject
@property (readonly) id<SMAbstractLocalFolder> folder;
@property (readonly) NSTimeInterval timestamp;
- (id)initWithFolder:(id<SMAbstractLocalFolder>)folder;
- (void)updateTimestamp;
@end

@implementation FolderEntry
- (id)initWithFolder:(id<SMAbstractLocalFolder>)folder {
    self = [super init];
    if(self) {
        _folder = folder;
        _timestamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}
- (void)updateTimestamp {
    _timestamp = [[NSDate date] timeIntervalSince1970];
}
@end

@implementation SMLocalFolderRegistry {
    NSMutableDictionary<NSString*, FolderEntry*> *_folders;
    NSMutableOrderedSet<FolderEntry*> *_accessTimeSortedFolders;
    NSComparator _accessTimeFolderComparator;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _folders = [NSMutableDictionary new];
        _accessTimeSortedFolders = [NSMutableOrderedSet new];
        _accessTimeFolderComparator = ^NSComparisonResult(id a, id b) {
            FolderEntry *f1 = (FolderEntry*)a;
            FolderEntry *f2 = (FolderEntry*)b;
            
            return f1.timestamp < f2.timestamp? NSOrderedAscending : (f1.timestamp > f2.timestamp? NSOrderedDescending : NSOrderedSame);
        };
    }
    
    return self;
}

- (NSArray<id<SMAbstractLocalFolder>>*)localFolders {
    NSArray<FolderEntry*> *folderEntires = _folders.allValues;
    NSMutableArray<id<SMAbstractLocalFolder>> *localFolders = [NSMutableArray array];
    
    for(FolderEntry *entry in folderEntires) {
        [localFolders addObject:entry.folder];
    }
    
    return localFolders;
}

- (void)updateFolderEntryAccessTime:(FolderEntry*)folderEntry {
    [_accessTimeSortedFolders removeObjectAtIndex:[self getFolderEntryIndex:folderEntry]];
    
    [folderEntry updateTimestamp];

    [_accessTimeSortedFolders insertObject:folderEntry atIndex:[self getFolderEntryIndex:folderEntry]];
}

- (id<SMAbstractLocalFolder>)getLocalFolderByName:(NSString*)localFolderName {
    FolderEntry *folderEntry = [_folders objectForKey:localFolderName];
    
    if(folderEntry == nil)
        return nil;
    
    [self updateFolderEntryAccessTime:folderEntry];
    
    return folderEntry.folder;
}

- (id<SMAbstractLocalFolder>)getLocalFolderByKind:(SMFolderKind)kind {
    NSAssert(kind != SMFolderKindRegular, @"regular folders should not be accessed by kind");
    
    for(FolderEntry *folderEntry in _folders.allValues) {
        if(folderEntry.folder.kind == kind) {
            return folderEntry.folder;
        }
    }
    
    return nil;
}

- (NSUInteger)getFolderEntryIndex:(FolderEntry*)folderEntry {
    return [_accessTimeSortedFolders indexOfObject:folderEntry inSortedRange:NSMakeRange(0, _accessTimeSortedFolders.count) options:NSBinarySearchingInsertionIndex usingComparator:_accessTimeFolderComparator];
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    return [self createLocalFolder:localFolderName remoteFolder:remoteFolderName kind:kind initialUnreadCount:initialUnreadCount initialUnreadCountProvided:YES syncWithRemoteFolder:syncWithRemoteFolder];
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    return [self createLocalFolder:localFolderName remoteFolder:remoteFolderName kind:kind initialUnreadCount:0 initialUnreadCountProvided:NO syncWithRemoteFolder:syncWithRemoteFolder];
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount initialUnreadCountProvided:(BOOL)initialUnreadCountProvided syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    FolderEntry *folderEntry = [_folders objectForKey:localFolderName];
    
    NSAssert(folderEntry == nil, @"folder %@ already created", localFolderName);
    
    id<SMAbstractLocalFolder> newLocalFolder = nil;
    
    if(_account.unified) {
        SMUnifiedLocalFolder *unifiedLocalFolder = [[SMUnifiedLocalFolder alloc] initWithUserAccount:(SMUnifiedAccount*)_account localFolderName:localFolderName kind:kind];

        newLocalFolder = unifiedLocalFolder;
        
        [self attachUnifiedLocalFolderToUserAccounts:unifiedLocalFolder];
    }
    else {
        SMLocalFolder *userLocalFolder;
        
        if(kind == SMFolderKindSearch) {
            userLocalFolder = [[SMSearchLocalFolder alloc] initWithUserAccount:_account localFolderName:localFolderName remoteFolderName:remoteFolderName];
        }
        else {
            if(initialUnreadCountProvided) {
                userLocalFolder = [[SMLocalFolder alloc] initWithUserAccount:_account localFolderName:localFolderName remoteFolderName:remoteFolderName kind:kind initialUnreadCount:initialUnreadCount syncWithRemoteFolder:syncWithRemoteFolder];
            }
            else {
                userLocalFolder = [[SMLocalFolder alloc] initWithUserAccount:_account localFolderName:localFolderName remoteFolderName:remoteFolderName kind:kind syncWithRemoteFolder:syncWithRemoteFolder];
            }
        }
        
        newLocalFolder = userLocalFolder;

        [self attachLocalFolderToUnifiedAccount:userLocalFolder];
    }
    
    folderEntry = [[FolderEntry alloc] initWithFolder:newLocalFolder];

    [folderEntry updateTimestamp];

    [_folders setValue:folderEntry forKey:localFolderName];

    [_accessTimeSortedFolders insertObject:folderEntry atIndex:[self getFolderEntryIndex:folderEntry]];
    
    return folderEntry.folder;
}

- (void)attachUnifiedLocalFolderToUserAccounts:(SMUnifiedLocalFolder*)unifiedLocalFolder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(_account.unified, @"account is not unified as expected");

    for(SMUserAccount *userAccount in appDelegate.accounts) {
        SMLocalFolder *userLocalFolder;
        
        if(unifiedLocalFolder.kind == SMFolderKindRegular) {
            userLocalFolder = (SMLocalFolder*)[[userAccount localFolderRegistry] getLocalFolderByName:unifiedLocalFolder.localName];
        }
        else {
            userLocalFolder = (SMLocalFolder*)[[userAccount localFolderRegistry] getLocalFolderByKind:unifiedLocalFolder.kind];
        }
        
        if(userLocalFolder) {
            NSAssert([userLocalFolder isKindOfClass:[SMLocalFolder class]], @"bad local folder type");
            
            SM_LOG_INFO(@"attaching local folder %@ to the new unified folder", userLocalFolder.localName);
            
            [unifiedLocalFolder attachLocalFolder:userLocalFolder];
        }
    }
}

- (void)attachLocalFolderToUnifiedAccount:(SMLocalFolder*)localFolder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(!_account.unified, @"account itself is unified");
    
    SMUnifiedLocalFolder *unifiedLocalFolder;
    if(localFolder.kind == SMFolderKindRegular) {
        unifiedLocalFolder = (SMUnifiedLocalFolder*)[[appDelegate.unifiedAccount localFolderRegistry] getLocalFolderByName:localFolder.localName];
    }
    else {
        unifiedLocalFolder = (SMUnifiedLocalFolder*)[[appDelegate.unifiedAccount localFolderRegistry] getLocalFolderByKind:localFolder.kind];
    }
    
    if(unifiedLocalFolder) {
        SM_LOG_INFO(@"attaching new local folder %@ to the unified account", localFolder.localName);
        
        [unifiedLocalFolder attachLocalFolder:localFolder];
    }
}

- (void)removeLocalFolder:(NSString*)folderName {
    FolderEntry *folderEntry = [_folders objectForKey:folderName];
    [folderEntry.folder stopLocalFolderSync:YES];

    [_folders removeObjectForKey:folderName];

    [_accessTimeSortedFolders removeObjectAtIndex:[self getFolderEntryIndex:folderEntry]];

    if(_account.unified) {
        SM_FATAL(@"removing folders from the unified account is not implemented");
    }
    else {
        [self detachLocalFolderFromUnifiedAccount:(SMLocalFolder*)folderEntry.folder];
    }
}

- (void)detachLocalFolderFromUnifiedAccount:(SMLocalFolder*)localFolder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSAssert(!_account.unified, @"account itself is unified");
    
    SMUnifiedLocalFolder *unifiedLocalFolder;
    if(localFolder.kind == SMFolderKindRegular) {
        unifiedLocalFolder = (SMUnifiedLocalFolder*)[[appDelegate.unifiedAccount localFolderRegistry] getLocalFolderByName:localFolder.localName];
    }
    else {
        unifiedLocalFolder = (SMUnifiedLocalFolder*)[[appDelegate.unifiedAccount localFolderRegistry] getLocalFolderByKind:localFolder.kind];
    }
    
    if(unifiedLocalFolder) {
        SM_LOG_INFO(@"detaching local folder %@ from the unified account", localFolder.localName);
        
        [unifiedLocalFolder detachLocalFolder:localFolder];
    }
}

@end
