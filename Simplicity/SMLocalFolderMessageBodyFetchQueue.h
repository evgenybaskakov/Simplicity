//
//  SMLocalFolderMessageBodyFetchQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/23/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMLocalFolder;

@interface SMLocalFolderMessageBodyFetchQueue : SMUserAccountDataObject

- (id)initWithUserAccount:(SMUserAccount*)account localFolder:(SMLocalFolder*)localFolder;
- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase;
- (void)cancelBodyLoading:(uint32_t)uid remoteFolder:(NSString*)remoteFolder;
- (void)stopBodiesLoading;

@end
