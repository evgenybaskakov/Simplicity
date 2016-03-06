//
//  SMFolderUIDDictionary.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/24/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMFolderUIDDictionary : NSObject

@property NSUInteger count;

- (NSObject*)objectForUID:(uint32_t)uid folder:(NSString*)folder;
- (void)setObject:(NSObject*)object forUID:(uint32_t)uid folder:(NSString*)folder;
- (void)removeObjectforUID:(uint32_t)uid folder:(NSString*)folder;
- (void)removeAllObjects;
- (void)enumerateAllObjects:(void (^)(NSObject*))block;

@end
