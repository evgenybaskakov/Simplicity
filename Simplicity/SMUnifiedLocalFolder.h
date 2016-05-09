//
//  SMUnifiedLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractLocalFolder.h"

@protocol SMAbstractAccount;

@class SMLocalFolder;

@interface SMUnifiedLocalFolder : SMUserAccountDataObject<SMAbstractLocalFolder>

- (id)initWithAccount:(SMUnifiedAccount*)account localFolderName:(NSString*)localFolderName kind:(SMFolderKind)kind;
- (void)attachLocalFolder:(SMLocalFolder*)localFolder;

@end
