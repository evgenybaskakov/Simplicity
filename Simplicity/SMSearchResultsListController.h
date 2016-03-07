//
//  SMSearchResultsListController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMSearchDescriptor;

@interface SMSearchResultsListController : NSObject

@property (readonly) MCOIndexSet *subjectSearchResults;
@property (readonly) MCOIndexSet *contactSearchResults;

- (BOOL)startNewSearch:(NSString*)searchPattern;

- (NSInteger)getSearchIndex:(NSString*)searchResultsLocalFolder;
- (NSUInteger)searchResultsCount;
- (SMSearchDescriptor*)getSearchResults:(NSUInteger)index;
- (void)searchHasFailed:(NSString*)searchResultsLocalFolder;

- (void)removeSearch:(NSInteger)index;
- (void)reloadSearch:(NSInteger)index;
- (void)stopSearch:(NSInteger)index;

- (void)stopLatestSearch;

- (Boolean)searchStopped:(NSInteger)index;

@end
