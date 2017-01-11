//
//  SMStringUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/16/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>

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

NSString *md5internal(const char *cptr, size_t len) {
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cptr, (CC_LONG)len, result);
    
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

+ (NSString*)md5:(NSString *)str {
    const char *cstr = [str UTF8String];
    return md5internal(cstr, strlen(cstr));
}

+ (NSString*)md5WithData:(NSData*)data {
    const char *cptr = [data bytes];
    return md5internal(cptr, data.length);
}

NSString *sha1internal(const char *cptr, size_t len) {
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cptr, (CC_LONG)len, result);
    
    return [NSString stringWithFormat:@"%02x%02x%02x%02x-%02x%02x%02x%02x-%02x%02x%02x%02x-%02x%02x%02x%02x-%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15],
            result[16], result[17], result[18], result[19]];
}

+ (NSString*)sha1:(NSString *)str {
    const char *cstr = [str UTF8String];
    return sha1internal(cstr, strlen(cstr));
}

+ (NSString*)sha1WithData:(NSData*)data {
    const char *cptr = [data bytes];
    return sha1internal(cptr, data.length);
}

+ (BOOL)cidURL:(NSString*)url contentId:(NSString**)contentId {
    if([url hasPrefix:@"cid:"]) {
        *contentId = [[url substringFromIndex:4] stringByRemovingPercentEncoding];
        return YES;
    }
    
    return NO;
}

@end
