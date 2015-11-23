//
//  SMAddressListElement.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAddressListElement.h"

#define EMAIL_DELIMITER @" — "

@implementation SMAddressListElement

- (id)initWithFirstName:(NSString*)firstName lastName:(NSString*)lastName email:(NSString*)email {
    self = [super init];
    
    if(self) {
        _firstName = firstName;
        _lastName = lastName;
        _email = email;
    }
    
    return self;
}

- (id)initWithStringRepresentation:(NSString*)string {
    self = [super init];
    
    if(self) {
        NSRange emailRange = [string rangeOfString:EMAIL_DELIMITER options:NSBackwardsSearch];
        
        if(emailRange.location == NSNotFound) {
            _firstName = nil;
            _lastName = nil;
            _email = string;
        }
        else {
            NSString *fullName = [string substringToIndex:emailRange.location];
            NSRange firstNameRange = [fullName rangeOfString:@" "];
            
            if(firstNameRange.location == NSNotFound) {
                _firstName = fullName;
                _lastName = nil;
            }
            else {
                _firstName = [fullName substringToIndex:firstNameRange.location];
                _lastName = [fullName substringFromIndex:firstNameRange.location + 1];
            }

            _email = [string substringFromIndex:emailRange.location + EMAIL_DELIMITER.length];
        }
    }
    
    return self;
}

- (NSString*)stringRepresentation {
    NSString *resultingString;
    
    if(_firstName != nil && _lastName != nil) {
        resultingString = [NSString stringWithFormat:@"%@ %@%@%@", _firstName, _lastName, EMAIL_DELIMITER, _email];
    }
    else if(_firstName != nil || _lastName != nil) {
        resultingString = [NSString stringWithFormat:@"%@%@%@", _firstName != nil? _firstName : _lastName, EMAIL_DELIMITER, _email];
    }
    else {
        NSAssert(_email != nil, @"no email address");
        resultingString = _email;
    }
    
    return resultingString;
}

- (NSString*)stringRepresentationShort {
    NSString *resultingString;
    
    if(_firstName != nil && _lastName != nil) {
        resultingString = [NSString stringWithFormat:@"%@ %@", _firstName, _lastName];
    }
    else if(_firstName != nil || _lastName != nil) {
        resultingString = _firstName != nil? _firstName : _lastName;
    }
    else {
        NSAssert(_email != nil, @"no email address");
        resultingString = _email;
    }
    
    return resultingString;
}

@end
