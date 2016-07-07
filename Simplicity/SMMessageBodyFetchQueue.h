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
- (void)fetchMessageBodyWithUID:(uint32_t)uid messageId:(uint64_t)messageId threadId:(uint64_t)threadId messageDate:(NSDate*)messageDate urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder;
- (void)cancelBodyFetchWithUID:(uint32_t)uid messageId:(uint64_t)messageId remoteFolder:(NSString*)remoteFolder localFolder:(SMLocalFolder*)localFolder;
- (void)pauseBodyFetchQueue;
- (void)resumeBodyFetchQueue;
- (void)stopBodyFetchQueue;

@end
