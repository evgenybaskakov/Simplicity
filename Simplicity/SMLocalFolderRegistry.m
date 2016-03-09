//
//  SMLocalFolderRegistry.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMSimplicityContainer.h"
#import "SMMessageListController.h"
#import "SMFolder.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMSearchFolder.h"

@interface FolderEntry : NSObject
@property (readonly) SMLocalFolder *folder;
@property (readonly) NSTimeInterval timestamp;
- (id)initWithFolder:(SMLocalFolder*)folder;
- (void)updateTimestamp;
@end

@implementation FolderEntry
- (id)initWithFolder:(SMLocalFolder*)folder {
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

static NSUInteger FOLDER_MEMORY_GREEN_ZONE_KB = 30 * 1024;
static NSUInteger FOLDER_MEMORY_YELLOW_ZONE_KB = 50 * 1024;
static NSUInteger FOLDER_MEMORY_RED_ZONE_KB = 100 * 1024;

@implementation SMLocalFolderRegistry {
    NSMutableDictionary *_folders;
    NSMutableOrderedSet *_accessTimeSortedFolders;
    NSComparator _accessTimeFolderComparator;
}

- (id)init {
    self = [super init];
    
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

- (void)updateFolderEntryAccessTime:(FolderEntry*)folderEntry {
    [_accessTimeSortedFolders removeObjectAtIndex:[self getFolderEntryIndex:folderEntry]];
    
    [folderEntry updateTimestamp];

    [_accessTimeSortedFolders insertObject:folderEntry atIndex:[self getFolderEntryIndex:folderEntry]];
}

- (SMLocalFolder*)getLocalFolder:(NSString*)localFolderName {
    FolderEntry *folderEntry = [_folders objectForKey:localFolderName];
    
    if(folderEntry == nil)
        return nil;
    
    [self updateFolderEntryAccessTime:folderEntry];
    
    return folderEntry.folder;
}

- (NSUInteger)getFolderEntryIndex:(FolderEntry*)folderEntry {
    return [_accessTimeSortedFolders indexOfObject:folderEntry inSortedRange:NSMakeRange(0, _accessTimeSortedFolders.count) options:NSBinarySearchingInsertionIndex usingComparator:_accessTimeFolderComparator];
}

- (SMLocalFolder*)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    FolderEntry *folderEntry = [_folders objectForKey:localFolderName];
    
    NSAssert(folderEntry == nil, @"folder %@ already created", localFolderName);
    
    SMLocalFolder *localFolder = (kind == SMFolderKindSearch)? [[SMSearchFolder alloc] initWithLocalFolderName:localFolderName remoteFolderName:remoteFolderName] : [[SMLocalFolder alloc] initWithLocalFolderName:localFolderName remoteFolderName:remoteFolderName kind:kind syncWithRemoteFolder:syncWithRemoteFolder];

    folderEntry = [[FolderEntry alloc] initWithFolder:localFolder];

    [folderEntry updateTimestamp];

    [_folders setValue:folderEntry forKey:localFolderName];

    [_accessTimeSortedFolders insertObject:folderEntry atIndex:[self getFolderEntryIndex:folderEntry]];
    
    return folderEntry.folder;
}

- (void)removeLocalFolder:(NSString*)folderName {
    FolderEntry *folderEntry = [_folders objectForKey:folderName];
    [folderEntry.folder stopMessagesLoading];

    [_folders removeObjectForKey:folderName];

    [_accessTimeSortedFolders removeObjectAtIndex:[self getFolderEntryIndex:folderEntry]];
}

- (void)keepFoldersMemoryLimit {
    uint64_t foldersMemoryKb = 0;
    for(FolderEntry *folderEntry in _accessTimeSortedFolders)
        foldersMemoryKb += [folderEntry.folder getTotalMemoryKb];

    // TODO: use the red zone
    (void)FOLDER_MEMORY_RED_ZONE_KB;

    if(foldersMemoryKb >= FOLDER_MEMORY_YELLOW_ZONE_KB) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMLocalFolder *currentLocalFolder = [[[appDelegate model] messageListController] currentLocalFolder];
        
        const uint64_t totalMemoryToReclaimKb = foldersMemoryKb - FOLDER_MEMORY_YELLOW_ZONE_KB;
        uint64_t totalMemoryReclaimedKb = 0;

        for(FolderEntry *folderEntry in _accessTimeSortedFolders) {
            if([folderEntry.folder.localName isEqualToString:currentLocalFolder.localName])
                continue;

            const uint64_t folderMemoryBeforeKb = [folderEntry.folder getTotalMemoryKb];

            NSAssert(totalMemoryReclaimedKb <= totalMemoryToReclaimKb, @"totalMemoryReclaimedKb %llu, totalMemoryToReclaimKb %llu", totalMemoryReclaimedKb, totalMemoryToReclaimKb);

            [folderEntry.folder reclaimMemory:(totalMemoryToReclaimKb - totalMemoryReclaimedKb)];

            const uint64_t folderMemoryAfterKb = [folderEntry.folder getTotalMemoryKb];
            
            NSAssert(folderMemoryAfterKb <= folderMemoryBeforeKb, @"folder memory changed from %llu to %llu", folderMemoryBeforeKb, folderMemoryAfterKb);

            const uint64_t totalFolderMemoryReclaimedKb = folderMemoryBeforeKb - folderMemoryAfterKb;

            SM_LOG_DEBUG(@"%llu Kb reclaimed for folder %@", totalFolderMemoryReclaimedKb, folderEntry.folder.localName);

            totalMemoryReclaimedKb += totalFolderMemoryReclaimedKb;
            
            if(totalMemoryReclaimedKb >= totalMemoryToReclaimKb)
                break;
        }

        SM_LOG_INFO(@"total %llu Kb reclaimed (%llu Kb was requested to reclaim, %lu Kb is the green zone, %lu Kb is the yellow zone)", totalMemoryReclaimedKb, totalMemoryToReclaimKb, FOLDER_MEMORY_GREEN_ZONE_KB, FOLDER_MEMORY_YELLOW_ZONE_KB);
    }
}

@end
