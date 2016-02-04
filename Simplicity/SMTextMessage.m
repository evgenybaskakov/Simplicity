//
//  SMTextMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/2/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMTextMessage.h"

@implementation SMTextMessage

- (id)initWithUID:(uint32_t)uid from:(NSString*)from toList:(NSArray<NSString*>*)toList ccList:(NSArray<NSString*>*)ccList subject:(NSString*)subject {
    self = [super init];
    
    if(self) {
        _uid = uid;
        _from = from;
        _toList = toList;
        _ccList = ccList;
        _subject = subject;
    }
    
    return self;
}

@end
