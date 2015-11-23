//
//  SMAddressBookController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <AddressBook/AddressBook.h>

#import "SMAddressBookController.h"

#define EMAIL_DELIMITER @" — "

@implementation SMAddressBookController

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix {
    NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    
    [self searchAddressBookProperty:kABEmailProperty value:prefix results:results];
    [self searchAddressBookProperty:kABFirstNameProperty value:prefix results:results];
    [self searchAddressBookProperty:kABLastNameProperty value:prefix results:results];
    
    return [results sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
        return [str1 compare:str2];
    }];
}

- (void)searchAddressBookProperty:(NSString*)property value:(NSString*)value results:(NSMutableOrderedSet*)results {
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
            NSString *resultingString;

            if(firstName != nil && lastName != nil) {
                resultingString = [NSString stringWithFormat:@"%@ %@%@%@", firstName, lastName, EMAIL_DELIMITER, email];
            }
            else if(firstName != nil || lastName != nil) {
                resultingString = [NSString stringWithFormat:@"%@%@%@", firstName != nil? firstName : lastName, EMAIL_DELIMITER, email];
            }
            else {
                resultingString = email;
            }
            
            [results addObject:resultingString];
        }
    }
}

@end
