//
//  SMMessageBodyFetchQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/23/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMLocalFolder;

@interface SMMessageBodyFetchQueue : SMUserAccountDataObject

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase remoteFolder:(NSString*)remoteFolderName localFolder:(SMLocalFolder*)localFolder;
- (void)cancelBodyFetch:(uint32_t)uid remoteFolder:(NSString*)remoteFolderName localFolder:(SMLocalFolder*)localFolder;
- (void)pauseBodyFetchQueue;
- (void)resumeBodyFetchQueue;
- (void)stopBodyFetchQueue;

@end
