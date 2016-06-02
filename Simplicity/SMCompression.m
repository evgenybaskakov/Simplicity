//
//  SMCompression.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/25/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#include <zlib.h>

#import "SMCompression.h"

@implementation SMCompression

+ (NSData*)gzipDeflate:(NSData*)data {
    if(data.length == 0) {
        return data;
    }
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in = (Bytef*)data.bytes;
    strm.avail_in = (uInt)data.length;
    
    if(deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return data;
    }
    
    NSMutableData *compressed = [NSMutableData dataWithLength:1026 * 16];
    
    do {
        if (strm.total_out >= [compressed length]) {
            [compressed increaseLengthBy: 16384];
        }
        
        strm.next_out = compressed.mutableBytes + strm.total_out;
        strm.avail_out = (uInt)compressed.length - (uInt)strm.total_out;
        
        deflate(&strm, Z_FINISH);
    } while (strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    compressed.length = strm.total_out;
    
    return compressed;
}

+ (NSData*)gzipInflate:(NSData*)data {
    if(data.length == 0) {
        return data;
    }
    
    NSUInteger full_length = data.length;
    NSUInteger half_length = data.length / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:full_length + half_length];
    
    z_stream strm;
    
    strm.next_in = (Bytef*)data.bytes;
    strm.avail_in = (uInt)data.length;
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if(inflateInit2(&strm, (15+32)) != Z_OK) {
        return nil;
    }
    
    BOOL done = NO;
    
    while(!done) {
        if(strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        
        strm.next_out = decompressed.mutableBytes + strm.total_out;
        strm.avail_out = (uInt)decompressed.length - (uInt)strm.total_out;
        
        const int status = inflate(&strm, Z_SYNC_FLUSH);
        
        if(status == Z_STREAM_END) {
            done = YES;
        }
        else if(status != Z_OK) {
            break;
        }
    }
    
    if(inflateEnd(&strm) != Z_OK) {
        return data;
    }
    
    if(done) {
        decompressed.length = strm.total_out;
        
        return decompressed;
    }
    else {
        return data;
    }
}

@end
