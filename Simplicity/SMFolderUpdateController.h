//
//  SMFolderUpdateController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMUserAccount;
@class SMLocalFolder;

@interface SMFolderUpdateController : NSObject

@property SMLocalFolder *watchedFolder;

- (id)initWithUserAccount:(SMUserAccount*)account folder:(SMLocalFolder*)folder;

- (void)scheduleFolderUpdate:(BOOL)now;
- (void)cancelScheduledFolderUpdate;

@end
