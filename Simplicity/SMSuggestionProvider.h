//
//  SMSuggestionProvider.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SMSuggestionProvider<NSObject>

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix;

@end
