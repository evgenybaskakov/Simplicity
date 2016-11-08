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

@class SMFolderDesc;

@interface SMAccountMailboxController : SMUserAccountDataObject<SMMailboxController>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)loadExistingFolders:(NSArray<SMFolderDesc*>*)folderDescs;
- (void)scheduleFolderListUpdate:(BOOL)now;
- (void)stopFolderListUpdate;

@end
