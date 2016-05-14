//
//  SMUnifiedMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMMailboxController.h"

@protocol SMAbstractAccount;

@interface SMUnifiedMailboxController : SMUserAccountDataObject<SMMailboxController>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;

@end
