//
//  SMAbstractSearchController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/24/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractAccount.h"

@class SMSearchToken;

@protocol SMAbstractSearchController

- (void)startNewSearchWithPattern:(NSString*)searchPattern searchTokens:(NSArray<SMSearchToken*>*)searchTokens;
- (void)stopLatestSearch;

@end
