//
//  SMMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMSimplicityContainer;

@interface SMMailboxController : SMUserAccountDataObject

- (id)initWithUserAccount:(SMUserAccount*)account;
- (void)initFolders;
- (void)loadExistingFolders:(NSArray*)folderDescs;
- (void)scheduleFolderListUpdate:(Boolean)now;
- (void)stopFolderListUpdate;
- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName;
- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName;
- (void)deleteFolder:(NSString*)oldFolderName;
- (NSUInteger)unseenMessagesCount:(NSString*)folderName;
- (NSUInteger)totalMessagesCount:(NSString*)folderName;

@end
