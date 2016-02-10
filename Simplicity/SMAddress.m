//
//  SMAddress.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMStringUtils.h"
#import "SMMessage.h"
#import "SMAddress.h"

#define EMAIL_DELIMITER @" — "

@implementation SMAddress {
    SMAddressMenuRepresentation _representationMode;
}

+ (NSArray*)mcoAddressesToAddressList:(NSArray*)mcoAddresses {
    NSMutableArray *addressList = [NSMutableArray array];
    
    for(MCOAddress *address in mcoAddresses) {
        SMAddress *addressElem = [[SMAddress alloc] initWithMCOAddress:address];
        [addressList addObject:addressElem];
    }
    
    return addressList;
}

+ (NSArray*)addressListToMCOAddresses:(NSArray*)mcoAddresses {
    NSMutableArray *addressList = [NSMutableArray array];
    
    for(SMAddress *address in mcoAddresses) {
        [addressList addObject:[address mcoAddress]];
    }
    
    return addressList;
}

+ (NSString*)displayAddress:(NSString*)address {
    NSArray *parts = [address componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
    
    if(parts.count == 1) {
        return [parts firstObject];
    }
    else if(parts.count == 2) {
        return [parts[0] stringByAppendingString:parts[1]];
    }
    else {
        NSString *result = @"";
        
        for(NSString *part in parts) {
            result = [result stringByAppendingString:part];
        }
        
        return result;
    }
}

+ (NSString*)extractEmailFromAddressString:(NSString*)address name:(NSString**)name {
    MCOAddress *mcoAddress = [MCOAddress addressWithNonEncodedRFC822String:address];
    NSString *mailbox = mcoAddress.mailbox;

    if(name != nil) {
        *name = mcoAddress.displayName;
    }
    
    return mailbox != nil? mailbox : address;
}

- (id)initWithFirstName:(NSString*)firstName lastName:(NSString*)lastName email:(NSString*)email representationMode:(SMAddressMenuRepresentation)representationMode {
    self = [super init];
    
    if(self) {
        _firstName = firstName;
        _lastName = lastName;
        _email = email;
        _representationMode = representationMode;
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
    _representationMode = SMAddressRepresentation_FirstNameFirst;

    string = [SMStringUtils trimString:string];
    
    if([string hasSuffix:@">"]) {
        NSRange range = [string rangeOfString:@"<" options:NSBackwardsSearch];
        
        if(range.length != 0) {
            [self extractFirstAndLastNames:[string substringToIndex:range.location]];

            _email = [string substringWithRange:NSMakeRange(range.location + 1, string.length - (range.location + 1) - 1)];
            
            return;
        }
    }
    
    NSRange emailRange = [string rangeOfString:EMAIL_DELIMITER options:NSBackwardsSearch];
    
    if(emailRange.location == NSNotFound) {
        _firstName = nil;
        _lastName = nil;
        _email = string;
    }
    else {
        [self extractFirstAndLastNames:[string substringToIndex:emailRange.location]];
        
        _email = [string substringFromIndex:emailRange.location + EMAIL_DELIMITER.length];
    }
}

- (void)extractFirstAndLastNames:(NSString*)fullName {
    fullName = [SMStringUtils trimString:fullName];
    
    NSRange firstNameRange = [fullName rangeOfString:@" "];
    
    if(firstNameRange.location == NSNotFound) {
        _firstName = fullName;
        _lastName = nil;
    }
    else {
        _firstName = [fullName substringToIndex:firstNameRange.location];
        _lastName = [fullName substringFromIndex:firstNameRange.location + 1];
    }
}

- (NSString*)stringRepresentationForMenu {
    NSString *resultingString;
    
    if(_representationMode == SMAddressRepresentation_EmailOnly) {
        NSAssert(_email != nil, @"no email address");
        resultingString = _email;
    }
    else {
        if(_firstName != nil && _lastName != nil) {
            if(_representationMode == SMAddressRepresentation_FirstNameFirst) {
                resultingString = [NSString stringWithFormat:@"%@ %@%@%@", _firstName, _lastName, EMAIL_DELIMITER, _email];
            }
            else {
                resultingString = [NSString stringWithFormat:@"%@ %@%@%@", _lastName, _firstName, EMAIL_DELIMITER, _email];
            }
        }
        else if(_firstName != nil || _lastName != nil) {
            resultingString = [NSString stringWithFormat:@"%@%@%@", _firstName != nil? _firstName : _lastName, EMAIL_DELIMITER, _email];
        }
        else {
            NSAssert(_email != nil, @"no email address");
            resultingString = _email;
        }
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
