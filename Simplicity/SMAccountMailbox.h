//
//  SMAccountMailbox.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMMailbox.h"
#import "SMUserAccountDataObject.h"

@class SMFolderDesc;

@interface SMAccountMailbox : SMUserAccountDataObject<SMMailbox>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (BOOL)loadExistingFolders:(NSArray<SMFolderDesc*>*)existingFolders;
- (Boolean)updateIMAPFolders:(NSArray<MCOIMAPFolder*>*)imapFolders vanishedFolders:(NSSet<SMFolderDesc*>**)vanishedFolders;
- (void)removeFolder:(NSString*)folderName;

@end
