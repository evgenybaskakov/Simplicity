//
//  SMRemoteImageLoadController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/17/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <string.h>

#import <WebKit/WebView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebScriptObject.h>
#import <WebKit/WebResourceLoadDelegate.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebPolicyDelegate.h>

#import <CommonCrypto/CommonDigest.h>

#import "SMLog.h"
#import "SMRemoteImageLoadController.h"

#define PERFECT_IMAGE_W 80
#define PERFECT_IMAGE_H 80

@interface WebPage : NSObject
@property NSString *htmlBody;
@property NSURL *baseURL;
@property void (^completionBlock)(NSImage*);
@property NSImage *bestImage;
@property NSUInteger imageCount;
@property NSUInteger imagesLoaded;
@property NSArray *imageDownloadTasks;
@end

@implementation WebPage
@end

@implementation SMRemoteImageLoadController {
    WebView *_webView;
    NSMutableArray<WebPage*> *_htmlPagesToLoad;
}

- (id)init {
    self = [super init];
    
    if(self) {
        // TODO: load cache from disk
        // TODO: start background refresh
        _webView = [[WebView alloc] init];
        _webView.resourceLoadDelegate = self;
        _webView.frameLoadDelegate = self;
        _webView.policyDelegate = self;
        
//        _webView.frameLoadDelegate = self;
//        _webView.downloadDelegate = self;
//        _webScript = [_webView windowScriptObject];
        _htmlPagesToLoad = [NSMutableArray array];
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

- (NSImage*)loadWebSiteImage:(NSString*)webSite completionBlock:(void (^)(NSImage*))completionBlock {
    NSArray *parts = [webSite componentsSeparatedByString:@"."];
    if(parts.count > 1) {
        webSite = [NSString stringWithFormat:@"%@.%@", parts[parts.count-2], parts[parts.count-1]];
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", webSite]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if(error == nil && data != nil && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse*)response).statusCode == 200) {
            NSString *htmlBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if(htmlBody == nil) {
                htmlBody = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }

            NSAssert(htmlBody, @"htmlBody is nil");
            
            SM_LOG_INFO(@"downloaded page: %@", webSite);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAssert(url, @"url is nil");
                NSAssert(htmlBody, @"htmlPage is nil");
                
                WebPage *page = [[WebPage alloc] init];
                page.baseURL = url;
                page.htmlBody = htmlBody;
                page.completionBlock = completionBlock;
                
                [_htmlPagesToLoad addObject:page];
                
                if(_htmlPagesToLoad.count == 1) {
                    SM_LOG_INFO(@"loading page: %@", page.baseURL);
                    [[_webView mainFrame] loadHTMLString:page.htmlBody baseURL:page.baseURL];
                }
            });
        }
//
////        dispatch_async(dispatch_get_main_queue(), ^{
////            completionBlock(image);
////        });
    }];

    [task resume];
    
    return nil;
}

//

- (void)consoleLog:(NSString *)aMessage {
    NSLog(@"JSLog: %@", aMessage);
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
    if (aSelector == @selector(consoleLog:)) {
        return NO;
    }
    
    return YES;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if(frame != sender.mainFrame) {
        return;
    }
    
    WebPage *webPage = _htmlPagesToLoad[0];

    NSAssert(_htmlPagesToLoad.count > 0, @"no html pages in the queue");
    NSAssert(webPage.baseURL, @"_htmlPagesToLoad[0].baseURL is nil");
    NSAssert(webPage.htmlBody, @"_htmlPagesToLoad[0].htmlBody is nil");

    SM_LOG_INFO(@"page loaded: %@", webPage.baseURL);
//    if([webPage.baseURL.absoluteString isEqualToString:@"http://amazon.com"]) {
//        SM_LOG_INFO(@"page loaded: %@", webPage.htmlBody);
//    }
    
    WebScriptObject *webScript = [sender windowScriptObject];
    [webScript setValue:self forKey:@"MyApp"];

    NSString *functionDefinition =
    @"function getImageUrls() {"
    "    var imageUrls = [];"
    "    var links = document.getElementsByTagName('link');"
    "    for(l in links) {"
    "        /*MyApp.consoleLog_('link: ' + links[l].rel);*/"
    "        if(links[l].rel === 'apple-touch-icon' || links[l].rel === 'apple-touch-icon-precomposed' || links[l].rel === 'icon' || links[l].rel === 'shortcut icon') {"
    "            if(links[l].href != undefined) {"
    "                imageUrls.push(links[l].href);"
    "            }"
    "        }"
    "    }"
    "    var metas = document.getElementsByTagName('meta');"
    "    for(m in metas) {"
    "        /*MyApp.consoleLog_('meta: ' + metas[m].name);*/"
    "        if(metas[m].name === 'msapplication-TileImage') {"
    "            if(metas[m].content != undefined) {"
    "                imageUrls.push(metas[m].content);"
    "            }"
    "        }"
    "    }"
    "    return JSON.stringify(imageUrls);"
    "}";
    
    [webScript evaluateWebScript:functionDefinition];
    
    NSString *ret = [sender stringByEvaluatingJavaScriptFromString:@"getImageUrls()"];

    NSError *error = nil;
    NSArray<NSString*> *parsedImageURLs = [NSJSONSerialization JSONObjectWithData:[ret dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];

//    if(parsedImageURLs != nil && parsedImageURLs.count != 0) {
//        NSLog(@"json: %@", parsedImageURLs);
//    }

    [_htmlPagesToLoad removeObjectAtIndex:0];
    
    if(_htmlPagesToLoad.count > 0) {
        WebPage *nextPage = _htmlPagesToLoad[0];
        NSAssert(nextPage.baseURL, @"nextPage.baseURL is nil");
        NSAssert(nextPage.htmlBody, @"htmlBody is nil");

        SM_LOG_INFO(@"loading page: %@", nextPage.baseURL);
        [[_webView mainFrame] loadHTMLString:nextPage.htmlBody baseURL:nextPage.baseURL];
    }
    
    NSMutableArray *imageURLs = [NSMutableArray arrayWithArray:parsedImageURLs];
    
    [imageURLs addObjectsFromArray:@[@"/touch-icon-iphone.png",
                                     @"/touch-icon-iphone-retina.png",
                                     @"/touch-icon-ipad.png",
                                     @"/touch-icon-ipad-retina.png",
                                     @"/apple-touch-icon-114x114.png",
                                     @"/apple-touch-icon-120x120.png",
                                     @"/apple-touch-icon-144x144.png",
                                     @"/apple-touch-icon-152x152.png",
                                     @"/apple-touch-icon-76x76.png",
                                     @"/apple-touch-icon-72x72.png",
                                     @"/apple-touch-icon-57x57.png",
                                     @"/apple-touch-icon-60x60.png",
                                     @"/favicon-96x96.png",
                                     @"/favicon-128.png",
                                     @"/favicon-196x196.png",
                                     @"/favicon-32x32.png",
                                     @"/favicon-16x16.png",
                                     @"/favicon.png",
                                     @"/favicon.ico"]];

    webPage.imageCount = imageURLs.count;
 
    NSMutableArray *tasks = [NSMutableArray array];
    for(NSString *u in imageURLs) {
        NSURL *url;
        if(u.length >= 2 && [u characterAtIndex:0] == '/' && [u characterAtIndex:1] == '/') {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"http:%@", u]];
        }
        else if(u.length >= 1 && [u characterAtIndex:0] == '/') {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", webPage.baseURL, u]];
        }
        else {
            url = [NSURL URLWithString:u];
        }
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // Check if this download is still needed
            if(webPage.completionBlock != nil) {
                if(error == nil && data != nil && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse*)response).statusCode == 200) {
                    NSImage *image = [[NSImage alloc] initWithData:data];
                    if(webPage.bestImage == nil || image.size.width > webPage.bestImage.size.width) {
                        webPage.bestImage = image;
                    }
                }
                
                BOOL lastImage = ++webPage.imagesLoaded == webPage.imageCount;
                BOOL perfectImageSize = (webPage.bestImage != nil && webPage.bestImage.size.width >= PERFECT_IMAGE_W && webPage.bestImage.size.height >= PERFECT_IMAGE_H);
                
                if(lastImage || perfectImageSize) {
                    SM_LOG_INFO(@"web page: %@, found %@ image (size %g x %g)", webPage.baseURL, perfectImageSize? @"perfect size" : @"largest available", webPage.bestImage.size.width, webPage.bestImage.size.height);
                    
                    for(NSURLSessionDataTask *t in webPage.imageDownloadTasks) {
                        [t cancel];
                    }
                    
                    void (^capturedCompletionBlock)(NSImage*) = webPage.completionBlock;
                    webPage.completionBlock = nil;

                    dispatch_async(dispatch_get_main_queue(), ^{
                        capturedCompletionBlock(webPage.bestImage);
                    });
                }
            }
        }];
        
        [task resume];
        
        [tasks addObject:task];
    }
    
    webPage.imageDownloadTasks = tasks;
}

-(BOOL)shouldSkiRequest:(NSURLRequest*)request{
    NSString *absoluteString = [request.URL.absoluteString lowercaseString];
    if([absoluteString hasSuffix:@".png"] || [absoluteString hasSuffix:@".jpg"] || [absoluteString hasSuffix:@".jpeg"] || [absoluteString hasSuffix:@".js"]){
        return YES;
    }
    return NO;
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
//    if([self shouldSkiRequest:request]){
//        return nil;
//    }
    return nil;
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
//    [listener use];
    if ([actionInformation objectForKey:WebActionElementKey]) {
        [listener ignore];
    } else {
        [listener use];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    [listener ignore];
}

@end
