//
//  SMUserAccountDataObject.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMUserAccountDataObject.h"

@implementation SMUserAccountDataObject

@synthesize account = _account;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super init];
    
    if(self) {
        _account = account;
    }
    
    return self;
}

@end
