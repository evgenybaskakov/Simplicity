//
//  SMUserAccount.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMUserAccount.h"

@implementation SMUserAccount

- (id)initWithIdx:(NSUInteger)idx model:(SMSimplicityContainer*)model {
    self = [super init];
    
    if(self) {
        _accountIdx = idx;
        _model = model;
    }
    
    return self;
}

@end
