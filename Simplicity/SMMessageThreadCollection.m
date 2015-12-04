//
//  SMMessageThreadCollection.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/16/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageThreadCollection.h"

@implementation SMMessageThreadCollection

- (id)init {
    self = [ super init ];
    
    if(self) {
        _messageThreads = [ NSMutableDictionary new ];
        _messageThreadsByDate = [ NSMutableOrderedSet new ];
    }
    
    return self;
}

@end
