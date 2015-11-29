//
//  SMAddressBookController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <AddressBook/AddressBook.h>

#import "SMLog.h"
#import "SMAddress.h"
#import "SMAddressBookController.h"

@implementation SMAddressBookController {
    NSMutableDictionary *_imageCache;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _imageCache = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix {
    NSMutableArray *results = [NSMutableArray array];
    
    [self searchAddressBookProperty:kABFirstNameProperty value:prefix results:results];
    [self searchAddressBookProperty:kABLastNameProperty value:prefix results:results];
    [self searchAddressBookProperty:kABEmailProperty value:prefix results:results];
    
    return results;
}

- (void)searchAddressBookProperty:(NSString*)property value:(NSString*)value results:(NSMutableArray*)resultArrays {
    NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [ABPerson searchElementForProperty:property label:nil key:nil value:value comparison:kABPrefixMatchCaseInsensitive];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];
    
    for(NSUInteger i = 0; i < foundRecords.count; i++) {
        ABRecord *record = foundRecords[i];
        NSString *firstName = [record valueForProperty:kABFirstNameProperty];
        NSString *lastName = [record valueForProperty:kABLastNameProperty];
        ABMultiValue *emails = [record valueForProperty:kABEmailProperty];
        
        for(NSUInteger j = 0; j < emails.count; j++) {
            NSString *email = [emails valueAtIndex:j];
            SMAddress *addressElement = [[SMAddress alloc] initWithFirstName:firstName lastName:lastName email:email];
            
            [results addObject:[addressElement stringRepresentationForMenu]];
        }
    }
    
    [resultArrays addObjectsFromArray:[results sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
        return [str1 compare:str2];
    }]];
}

- (NSData*)imageDataForEmail:(NSString*)email {
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:email comparison:kABEqualCaseInsensitive];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];
    
    for(NSUInteger i = 0; i < foundRecords.count; i++) {
        ABRecord *record = foundRecords[i];
        
        if([record isKindOfClass:[ABRecord class]]) {
            ABPerson *person = (ABPerson*)record;
            
            if(person.imageData != nil) {
                return person.imageData;
            }
        }
    }
    
    return nil;
}

- (NSImage*)pictureForEmail:(NSString*)email {
    NSImage *image = [_imageCache objectForKey:email];
    
    if(image != nil) {
        return image;
    }
    
    NSData *imageData = [self imageDataForEmail:email];
    
    if(imageData == nil) {
        return [NSImage imageNamed:NSImageNameUserGuest];
    }
    
    image = [[NSImage alloc] initWithData:imageData];
    
    [_imageCache setObject:image forKey:email];
    
    return image;
}

- (BOOL)addressIsKnown:(SMAddress*)address {
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *searchFirstName = address.firstName? [ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:address.firstName comparison:kABEqualCaseInsensitive] : nil;
    ABSearchElement *searchLastName = address.lastName? [ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:address.lastName comparison:kABEqualCaseInsensitive] : nil;
    
    NSAssert(address.email, @"address.email is nil");
    ABSearchElement *searchEmail = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:address.email comparison:kABEqualCaseInsensitive];

    ABSearchElement *fullSearch;
    
    if(searchFirstName && searchLastName) {
        ABSearchElement *searchFullName = [ABSearchElement searchElementForConjunction:kABSearchAnd children:@[searchFirstName, searchLastName]];
        fullSearch = [ABSearchElement searchElementForConjunction:kABSearchOr children:@[searchFullName, searchEmail]];
    }
    else {
        fullSearch = searchEmail;
    }

    NSArray *foundRecords = [ab recordsMatchingSearchElement:fullSearch];

    if(foundRecords.count > 0) {
        SM_LOG_INFO(@"Address '%@' found in address book (%lu records)", address.stringRepresentationDetailed, foundRecords.count);
        return YES;
    }
    else {
        SM_LOG_INFO(@"Address '%@' not found in address book", address.stringRepresentationDetailed);
        return NO;
    }
}

@end
