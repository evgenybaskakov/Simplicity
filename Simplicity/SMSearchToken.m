//
//  SMSearchToken.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMSearchToken.h"

@implementation SMSearchToken

- (id)initWithKind:(SearchExpressionKind)kind string:(NSString*)string {
    self = [super init];
    
    if(self) {
        SM_LOG_NOISE(@"kind %u, string %@", (unsigned int)kind, string);
        
        _kind = kind;
        _string = string;
    }
    
    return self;
}

@end
