//
//  SMSearchDescriptor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/15/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMSearchDescriptor.h"

@implementation SMSearchDescriptor

- (id)init:(NSString*)searchPattern localFolder:(NSString*)localFolder remoteFolder:(NSString*)remoteFolderName {
    self = [super init];
    
    if(self) {
        _searchPattern = searchPattern;
        _localFolder = localFolder;
        _remoteFolder = remoteFolderName;
        _searchFailed = false;
        _searchStopped = false;
        _messagesLoadingStarted = false;
    }
    
    return self;
}

- (void)clearState {
    _searchFailed = false;
    _searchStopped = false;
    _messagesLoadingStarted = false;
}

@end
