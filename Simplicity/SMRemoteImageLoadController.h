//
//  SMRemoteImageLoadController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/17/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebResourceLoadDelegate.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebPolicyDelegate.h>

#import <Foundation/Foundation.h>

@interface SMRemoteImageLoadController : NSObject<WebResourceLoadDelegate, WebFrameLoadDelegate, WebPolicyDelegate>

- (NSImage*)loadAvatar:(NSString*)email completionBlock:(void (^)(NSImage*))completionBlock;
- (NSImage*)loadWebSiteImage:(NSString*)webSite completionBlock:(void (^)(NSImage*))completionBlock;

@end
