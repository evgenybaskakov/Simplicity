//
//  SMAddressBookController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMSuggestionProvider.h"

@class SMAddress;

@interface SMAddressBookController : NSObject<SMSuggestionProvider>

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix;
- (NSImage*)pictureForEmail:(NSString*)email;
- (BOOL)findAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;
- (BOOL)addAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;

@end
