//
//  SMLocalFolderRegistry.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMFolder.h"

@protocol SMAbstractLocalFolder;

@interface SMLocalFolderRegistry : SMUserAccountDataObject

@property (readonly) NSArray<id<SMAbstractLocalFolder>> *localFolders;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount syncWithRemoteFolder:(BOOL)syncWithRemoteFolder;
- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(BOOL)syncWithRemoteFolder;
- (id<SMAbstractLocalFolder>)getLocalFolderByName:(NSString*)folderName;
- (id<SMAbstractLocalFolder>)getLocalFolderByKind:(SMFolderKind)kind;
- (void)removeLocalFolder:(NSString*)folderName;

@end
