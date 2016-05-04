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

@class SMLocalFolder;

@interface SMLocalFolderRegistry : SMUserAccountDataObject

@property (readonly) NSArray<SMLocalFolder*> *localFolders;

- (id)initWithUserAccount:(NSObject<SMAbstractAccount>*)account;
- (SMLocalFolder*)createLocalFolder:(NSString*)localFolderName remoteFolder:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder;
- (SMLocalFolder*)getLocalFolder:(NSString*)folderName;
- (void)removeLocalFolder:(NSString*)folderName;
- (void)keepFoldersMemoryLimit;

@end
