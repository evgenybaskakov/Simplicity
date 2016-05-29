//
//  SMSearchRequestInputController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMSearchRequestInputController : NSObject

- (void)clearSuggestionsForAccount:(SMUserAccount*)account;
- (void)addContentsSectionToSuggestionsMenu:(NSString*)topLevelItem account:(SMUserAccount*)account;
- (void)addContactsSectionToSuggestionsMenu:(NSString *)topLevelItem contacts:(NSArray*)contacts account:(SMUserAccount*)account;
- (void)addSubjectsSectionToSuggestionsMenu:(NSString *)topLevelItem subjects:(NSArray*)subjects account:(SMUserAccount*)account;
- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern;

@end
