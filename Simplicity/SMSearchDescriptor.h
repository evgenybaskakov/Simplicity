//
//  SMSearchDescriptor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/15/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMSearchDescriptor : NSObject

@property (readonly) NSString *searchPattern;
@property (readonly) NSString *localFolder;
//@property (readonly) NSString *remoteFolder; // TODO: this will be more sophisticated

@property BOOL searchFailed;
@property BOOL searchStopped;
@property BOOL messagesLoadingStarted;

- (id)init:(NSString*)searchPattern localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolderName;

- (void)clearState;

@end
