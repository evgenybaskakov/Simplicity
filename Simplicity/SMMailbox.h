//
//  SMFolderTree.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/22/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMFolder.h"

@interface SMMailbox : SMUserAccountDataObject

@property (readonly) SMFolder *rootFolder;
@property (readonly) SMFolder *inboxFolder;
@property (readonly) SMFolder *outboxFolder;
@property (readonly) SMFolder *sentFolder;
@property (readonly) SMFolder *draftsFolder;
@property (readonly) SMFolder *importantFolder;
@property (readonly) SMFolder *starredFolder;
@property (readonly) SMFolder *spamFolder;
@property (readonly) SMFolder *allMailFolder;
@property (readonly) SMFolder *trashFolder;

@property (readonly) NSArray *mainFolders;
@property (readonly) NSArray *folders;

@property (readonly) NSArray *alwaysSyncedFolders;

@property SMFolder *selectedFolder;

- (id)initWithUserAccount:(SMUserAccount *)account;
- (BOOL)loadExistingFolders:(NSArray*)existingFolders;
- (Boolean)updateIMAPFolders:(NSArray*)imapFolders vanishedFolders:(NSMutableArray*)vanishedFolders;
- (SMFolder*)getFolderByName:(NSString*)folderName;
- (void)removeFolder:(NSString*)folderName;
- (NSString*)constructFolderName:(NSString*)folderName parent:(NSString*)parentFolderName;

@end
