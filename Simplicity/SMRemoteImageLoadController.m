//
//  SMRemoteImageLoadController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/17/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <string.h>
#import <CommonCrypto/CommonDigest.h>

#import "SMRemoteImageLoadController.h"

@implementation SMRemoteImageLoadController

- (id)init {
    self = [super init];
    
    if(self) {
        // TODO: load cache from disk
        // TODO: start background refresh
    }
    
    return self;
}

- (NSString*)md5:(NSString*)str {
    const char *cstr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

- (NSImage*)loadAvatar:(NSString*)email completionBlock:(void (^)(NSImage*))completionBlock {
    // TODO: load from cache, return immediately

    NSString *emailMD5 = [self md5:email];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@?d=404&size=%d", emailMD5, 128]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSImage *image = nil;
        
//        NSLog(@"response: %@", response);
        if(error == nil && data != nil && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse*)response).statusCode == 200) {
            image = [[NSImage alloc] initWithData:data];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(image);
        });
    }];
    
    [task resume];
    
    return nil;
}

@end
