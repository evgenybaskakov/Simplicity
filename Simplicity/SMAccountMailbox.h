//
//  SMAccountMailbox.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMMailbox.h"
#import "SMUserAccountDataObject.h"

@interface SMAccountMailbox : SMUserAccountDataObject<SMMailbox>

@property (readonly) NSArray *alwaysSyncedFolders;

- (id)initWithUserAccount:(NSObject<SMAbstractAccount>*)account;
- (BOOL)loadExistingFolders:(NSArray*)existingFolders;
- (Boolean)updateIMAPFolders:(NSArray*)imapFolders vanishedFolders:(NSMutableArray*)vanishedFolders;
- (void)removeFolder:(NSString*)folderName;

@end
