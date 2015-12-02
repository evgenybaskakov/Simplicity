//
//  SMStringUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/16/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMStringUtils.h"

// Taken from here: http://www.cocoawithlove.com/2009/06/verifying-that-string-is-email-address.html.
static NSString *emailRegEx =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";

@implementation SMStringUtils

+ (BOOL)string:(NSString *)string hasPrefix:(NSString *)prefix caseInsensitive:(BOOL)caseInsensitive {
    if (!caseInsensitive) {
        return [string hasPrefix:prefix];
    }
    
    const NSStringCompareOptions options = NSAnchoredSearch|NSCaseInsensitiveSearch;
    NSRange prefixRange = [string rangeOfString:prefix options:options];
    return prefixRange.location == 0 && prefixRange.length > 0;
}

+ (BOOL)emailAddressValid:(NSString*)emailAddress {
    if(emailAddress == nil) {
        return NO;
    }
    
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegEx];
    return [emailTest evaluateWithObject:emailAddress];
}

// TODO: cache trimmed strings?
+ (NSString*)trimString:(NSString*)str {
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
