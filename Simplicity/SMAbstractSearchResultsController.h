//
//  SMAbstractSearchResultsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/24/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractAccount.h"

@protocol SMAbstractSearchResultsController

- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern;
- (void)stopLatestSearch;

@end
