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

@property (readonly) NSImage *defaultUserImage;

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix;
- (NSImage*)pictureForAddress:(SMAddress*)address;
- (BOOL)findAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;
- (BOOL)addAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;
- (void)openAddressInAddressBook:(NSString*)addressUniqueId edit:(BOOL)edit;

@end
