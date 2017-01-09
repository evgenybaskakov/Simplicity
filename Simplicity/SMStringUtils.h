//
//  SMStringUtils.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/16/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMStringUtils : NSObject

+ (BOOL)string:(NSString *)string hasPrefix:(NSString *)prefix caseInsensitive:(BOOL)caseInsensitive;
+ (BOOL)emailAddressValid:(NSString*)emailAddress;
+ (NSString*)trimString:(NSString*)str;
+ (NSString*)md5:(NSString*)str;
+ (NSString*)md5WithData:(NSData*)data;
+ (NSString*)sha1:(NSString *)str;
+ (NSString*)sha1WithData:(NSData*)data;
+ (BOOL)cidURL:(NSString*)url contentId:(NSString**)contentId;

@end
