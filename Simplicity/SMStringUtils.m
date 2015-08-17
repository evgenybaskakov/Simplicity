//
//  SMStringUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/16/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMStringUtils.h"

@implementation SMStringUtils

+ (BOOL)string:(NSString *)string hasPrefix:(NSString *)prefix caseInsensitive:(BOOL)caseInsensitive {
    if (!caseInsensitive) {
        return [string hasPrefix:prefix];
    }
    
    const NSStringCompareOptions options = NSAnchoredSearch|NSCaseInsensitiveSearch;
    NSRange prefixRange = [string rangeOfString:prefix options:options];
    return prefixRange.location == 0 && prefixRange.length > 0;
}

@end
