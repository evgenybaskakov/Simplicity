//
//  SMAccountMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMMailboxController.h"
#import "SMUserAccountDataObject.h"

@class SMFolder;

@interface SMAccountMailboxController : SMUserAccountDataObject<SMMailboxController>

@property SMFolder *selectedFolder;

- (id)initWithUserAccount:(SMUserAccount*)account;
- (void)initFolders;
- (void)loadExistingFolders:(NSArray*)folderDescs;
- (void)scheduleFolderListUpdate:(Boolean)now;
- (void)stopFolderListUpdate;

@end
