//
//  SMSearchFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLocalFolder.h"

@interface SMSearchFolder : SMLocalFolder

- (id)initWithLocalFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName;

// loads the messages specified by their UIDs from the remote folder
- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs updateResults:(BOOL)updateResults;

@end
