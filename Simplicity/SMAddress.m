//
//  SMAddress.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMMessage.h"
#import "SMAddress.h"

#define EMAIL_DELIMITER @" — "

@implementation SMAddress

+ (NSArray*)mcoAddressesToAddressList:(NSArray*)mcoAddresses {
    NSMutableArray *addressList = [NSMutableArray array];
    
    for(MCOAddress *address in mcoAddresses) {
        SMAddress *addressElem = [[SMAddress alloc] initWithMCOAddress:address];
        [addressList addObject:addressElem];
    }
    
    return addressList;
}

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
        [self initInternalWithString:string];
    }
    
    return self;
}

- (id)initWithMCOAddress:(MCOAddress*)mcoAddress {
    self = [super init];
    
    if(self) {
        NSString *parsedAddress = [SMMessage parseAddress:mcoAddress];
        NSAssert(parsedAddress != nil, @"parsedAddress is nil");

        if([parsedAddress rangeOfString:@"@"].location == NSNotFound) {
            [self initInternalWithString:[NSString stringWithFormat:@"%@%@%@", parsedAddress, EMAIL_DELIMITER, [mcoAddress mailbox]]];
        }
        else {
            [self initInternalWithString:parsedAddress];
        }
    }
    
    return self;
}

- (void)initInternalWithString:(NSString*)string {
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

- (NSString*)stringRepresentationForMenu {
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

- (NSString*)stringRepresentationDetailed {
    NSString *resultingString;
    
    if(_firstName != nil && _lastName != nil) {
        resultingString = [NSString stringWithFormat:@"%@ %@ <%@>", _firstName, _lastName, _email];
    }
    else if(_firstName != nil || _lastName != nil) {
        resultingString = [NSString stringWithFormat:@"%@ <%@>", _firstName != nil? _firstName : _lastName, _email];
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

- (MCOAddress*)mcoAddress {
    if(_firstName != nil && _lastName != nil) {
        return [MCOAddress addressWithDisplayName:[NSString stringWithFormat:@"%@ %@", _firstName, _lastName] mailbox:_email];
    }
    else if(_firstName != nil || _lastName != nil) {
        return [MCOAddress addressWithDisplayName:(_firstName? _firstName : _lastName) mailbox:_email];
    }
    else {
        return [MCOAddress addressWithMailbox:_email];
    }
}

@end
