//
//  SMCompression.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/25/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMCompression : NSObject

+ (NSData*)gzipDeflate:(NSData*)data;
+ (NSData*)gzipInflate:(NSData*)data;

@end
