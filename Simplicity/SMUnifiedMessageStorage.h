//
//  SMUnifiedMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractMessageStorage.h"

@protocol SMAbstractAccount;

@class SMUnifiedAccount;

@interface SMUnifiedMessageStorage : SMUserAccountDataObject<SMAbstractMessageStorage>

- (id)initWithUserAccount:(SMUnifiedAccount*)account;

@end
