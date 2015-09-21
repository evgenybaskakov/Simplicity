//
//  SMFolderTree.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMFolder.h"

@interface SMMailbox : NSObject

@property (readonly) SMFolder *rootFolder;
@property (readonly) SMFolder *inboxFolder;
@property (readonly) SMFolder *sentFolder;
@property (readonly) SMFolder *draftsFolder;
@property (readonly) SMFolder *importantFolder;
@property (readonly) SMFolder *starredFolder;
@property (readonly) SMFolder *spamFolder;
@property (readonly) SMFolder *allMailFolder;
@property (readonly) SMFolder *trashFolder;

@property (readonly) NSArray *mainFolders;
@property (readonly) NSOrderedSet *favoriteFolders;
@property (readonly) NSArray *folders;

- (void)loadExistingFolders:(NSArray*)existingFolders;
- (Boolean)updateIMAPFolders:(NSArray*)imapFolders;

- (SMFolder*)getFolderByKind:(SMFolderKind)kind;
- (SMFolder*)getFolderByName:(NSString*)folderName;
- (NSString*)constructFolderName:(NSString*)folderName parent:(NSString*)parentFolderName;

- (void)addFavoriteFolderWithName:(NSString*)name;
- (void)removeFavoriteFolderWithName:(NSString*)name;

@end
