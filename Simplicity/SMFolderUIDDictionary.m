//
//  SMFolderUIDDictionary.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/24/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFolderUIDDictionary.h"

@implementation SMFolderUIDDictionary {
    NSMutableDictionary *_dict;
}

- (id)init {
    self = [super init];

    if(self) {
        _dict = [NSMutableDictionary dictionary];
        _count = 0;
    }
    
    return self;
}

- (NSObject*)objectForUID:(uint32_t)uid folder:(NSString*)folder {
    NSDictionary *folderDict = [_dict objectForKey:folder];
    
    if(folderDict != nil) {
        return [folderDict objectForKey:[NSNumber numberWithUnsignedInt:uid]];
    }
    
    return nil;
}

- (void)setObject:(NSObject*)object forUID:(uint32_t)uid folder:(NSString*)folder {
    NSMutableDictionary *folderDict = [_dict objectForKey:folder];
    
    if(folderDict == nil) {
        folderDict = [NSMutableDictionary dictionary];
        
        [_dict setObject:folderDict forKey:folder];
    }
    
    NSUInteger cnt = folderDict.count;
    
    [folderDict setObject:object forKey:[NSNumber numberWithUnsignedInt:uid]];
    
    NSAssert(folderDict.count == cnt || folderDict.count == cnt + 1, @"dict count changed from %lu to %lu", cnt, folderDict.count);
    
    if(folderDict.count == cnt + 1) {
        _count++;
    }
}

- (void)removeObjectforUID:(uint32_t)uid folder:(NSString*)folder {
    NSMutableDictionary *folderDict = [_dict objectForKey:folder];
    
    if(folderDict != nil) {
        NSUInteger cnt = folderDict.count;
        
        [folderDict removeObjectForKey:[NSNumber numberWithUnsignedInt:uid]];
        
        NSAssert(folderDict.count == cnt || folderDict.count + 1 == cnt, @"dict count changed from %lu to %lu", cnt, folderDict.count);
        
        if(folderDict.count + 1 == cnt) {
            _count--;
        }
    }
}

- (void)removeAllObjects {
    [_dict removeAllObjects];
    
    _count = 0;
}

@end
