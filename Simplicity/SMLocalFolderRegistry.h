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
- (id<SMAbstractLocalFolder>)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder;
- (id<SMAbstractLocalFolder>)getLocalFolder:(NSString*)folderName;
- (void)removeLocalFolder:(NSString*)folderName;
- (void)keepFoldersMemoryLimit;

@end
