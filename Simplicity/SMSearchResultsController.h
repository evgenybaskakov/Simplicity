//
//  SMSearchResultsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractSearchResultsController.h"
#import "SMUserAccountDataObject.h"

@interface SMSearchResultsController : SMUserAccountDataObject<SMAbstractSearchResultsController>

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;

@end
