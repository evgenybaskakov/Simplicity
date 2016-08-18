//
//  SMRemoteImageLoadController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/17/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMRemoteImageLoadController : NSObject

- (NSImage*)loadAvatar:(NSString*)email completionBlock:(void (^)(NSImage*))completionBlock;

@end
