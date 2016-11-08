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

@implementation SMLocalFolderRegistry {
    NSMutableDictionary<NSString*, id<SMAbstractLocalFolder>> *_folders;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _folders = [NSMutableDictionary new];
    }
    
    return self;
}

- (NSArray<id<SMAbstractLocalFolder>>*)localFolders {
    NSArray<id<SMAbstractLocalFolder>> *folderEntires = _folders.allValues;
    NSMutableArray<id<SMAbstractLocalFolder>> *localFolders = [NSMutableArray array];
    
    for(id<SMAbstractLocalFolder> folder in folderEntires) {
        [localFolders addObject:folder];
    }
    
    return localFolders;
}

- (id<SMAbstractLocalFolder>)getLocalFolderByName:(NSString*)localFolderName {
    return [_folders objectForKey:localFolderName];
}

- (id<SMAbstractLocalFolder>)getLocalFolderByKind:(SMFolderKind)kind {
    NSAssert(kind != SMFolderKindRegular, @"regular folders should not be accessed by kind");
    
    for(id<SMAbstractLocalFolder> folder in _folders.allValues) {
        if(folder.kind == kind) {
            return folder;
        }
    }
    
    return nil;
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount syncWithRemoteFolder:(BOOL)syncWithRemoteFolder {
    return [self createLocalFolder:localFolderName remoteFolder:remoteFolderName kind:kind initialUnreadCount:initialUnreadCount initialUnreadCountProvided:YES syncWithRemoteFolder:syncWithRemoteFolder];
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(BOOL)syncWithRemoteFolder {
    return [self createLocalFolder:localFolderName remoteFolder:remoteFolderName kind:kind initialUnreadCount:0 initialUnreadCountProvided:NO syncWithRemoteFolder:syncWithRemoteFolder];
}

- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount initialUnreadCountProvided:(BOOL)initialUnreadCountProvided syncWithRemoteFolder:(BOOL)syncWithRemoteFolder {
    id<SMAbstractLocalFolder> folder = [_folders objectForKey:localFolderName];
    NSAssert(!folder, @"folder %@ already created", localFolderName);
    
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
    
    [_folders setValue:newLocalFolder forKey:localFolderName];
    return newLocalFolder;
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
    id<SMAbstractLocalFolder> folder = [_folders objectForKey:folderName];
    [folder stopLocalFolderSync:YES];

    [_folders removeObjectForKey:folderName];

    if(_account.unified) {
        SM_FATAL(@"removing folders from the unified account is not implemented");
    }
    else {
        [self detachLocalFolderFromUnifiedAccount:(SMLocalFolder*)folder];
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
