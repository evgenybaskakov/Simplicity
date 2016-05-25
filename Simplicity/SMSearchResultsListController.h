//
//  SMSearchResultsListController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMSearchDescriptor;

@interface SMSearchResultsListController : SMUserAccountDataObject

@property (readonly) MCOIndexSet *subjectSearchResults;
@property (readonly) MCOIndexSet *contactSearchResults;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern;
- (SMSearchDescriptor*)getSearchResults:(NSUInteger)index;
- (void)stopLatestSearch;

@end
