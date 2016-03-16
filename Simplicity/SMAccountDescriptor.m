//
//  SMAccountDescriptor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAccountDescriptor.h"

@implementation SMAccountDescriptor

- (id)initWithIdx:(NSUInteger)idx {
    self = [super init];
    
    if(self) {
        _accountIdx = idx;
    }
    
    return self;
}

@end
