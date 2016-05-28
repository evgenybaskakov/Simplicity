//
//  SMUnifiedSearchController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/25/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractSearchController.h"

@interface SMUnifiedSearchController : SMUserAccountDataObject<SMAbstractSearchController>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;

@end
