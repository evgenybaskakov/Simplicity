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
- (NSImage*)loadPictureForAddress:(SMAddress*)address searchNetwork:(BOOL)searchNetwork allowWebSiteImage:(BOOL)allowWebSiteImage tag:(NSInteger)tag completionBlock:(void (^)(NSImage*, NSInteger))completionBlock;
- (BOOL)findAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;
- (BOOL)addAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId;
- (void)openAddressInAddressBook:(NSString*)addressUniqueId edit:(BOOL)edit;

@end
