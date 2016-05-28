//
//  SMAccountSearchController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractSearchController.h"
#import "SMUserAccountDataObject.h"

@interface SMAccountSearchController : SMUserAccountDataObject<SMAbstractSearchController>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;

@end
