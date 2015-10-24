//
//  SMLocalFolderMessageBodyFetchQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/23/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMLocalFolder;

@interface SMLocalFolderMessageBodyFetchQueue : NSObject

- (id)initWithLocalFolder:(SMLocalFolder*)localFolder;
- (void)fetchMessageBody:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent tryLoadFromDatabase:(BOOL)tryLoadFromDatabase;
- (void)cancelBodyLoading:(uint32_t)uid;
- (void)stopBodiesLoading;

@end
