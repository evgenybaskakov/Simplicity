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
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMRemoteImageLoadController.h"

#define IMAGE_FILE_CACHE_EXPIRATION_TIME_SEC (60 * 60 * 24 * 28) // four weeks

#define PERFECT_IMAGE_W 80
#define PERFECT_IMAGE_H 80

@interface WebPage : NSObject
@property NSString *webSite;
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
    NSMutableDictionary<NSString*,NSImage*> *_imageCache;
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
        _htmlPagesToLoad = [NSMutableArray array];
        _imageCache = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (NSURL*)imageCacheDir {
    NSURL *appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    return [appDataDir URLByAppendingPathComponent:[NSString stringWithFormat:@"ImageCache"] isDirectory:YES];
}

- (void)saveImageToDisk:(NSString*)imageName image:(NSImage*)image {
    NSURL *dirUrl = [self imageCacheDir];
    
    NSString *dirPath = [dirUrl path];
    NSAssert(dirPath != nil, @"dirPath is nil");
    
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        SM_LOG_ERROR(@"failed to create directory '%@', error: %@", dirPath, error);
        return;
    }
    
    NSURL *imageFileUrl = [dirUrl URLByAppendingPathComponent:imageName];
    NSString *imageFilePath = [imageFileUrl path];
    
    NSBitmapImageRep *imageRep = (NSBitmapImageRep*)[[image representations] objectAtIndex: 0];
    NSData *imageData = [imageRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    
    if([imageData writeToFile:imageFilePath atomically:YES]) {
        SM_LOG_DEBUG(@"file %@ (%lu bytes) written successfully", imageFilePath, (unsigned long)[imageData length]);
    } else {
        SM_LOG_ERROR(@"cannot write file '%@' (%lu bytes)", imageFilePath, (unsigned long)[imageData length]);
    }
}

- (NSImage*)loadImageFromDisk:(NSString*)imageName {
    NSURL *dirUrl = [self imageCacheDir];
    
    NSString *dirPath = [dirUrl path];
    NSAssert(dirPath != nil, @"dirPath is nil");
    
    NSURL *imageFileUrl = [dirUrl URLByAppendingPathComponent:imageName];
    NSString *imageFilePath = [imageFileUrl path];

    BOOL imageFileValid = NO;
    NSDictionary *fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:imageFilePath error:nil];
    if(fileAttribs) {
        NSDate *creationTime = [fileAttribs objectForKey:NSFileCreationDate];
        
        if(creationTime) {
            NSTimeInterval timeDiff = [[NSDate date] timeIntervalSinceDate:creationTime];
            
            if(timeDiff < IMAGE_FILE_CACHE_EXPIRATION_TIME_SEC) {
                imageFileValid = YES;
            }
        }
    }
    
    if(!imageFileValid) {
        [[NSFileManager defaultManager] removeItemAtPath:imageFilePath error:nil];
        return nil;
    }
    
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imageFilePath];
    return image;
}

- (NSString*)webSiteFromEmail:(NSString*)email {
    NSArray *parts = [email componentsSeparatedByString:@"@"];
    if(parts.count == 2) {
        NSString *webSite = parts[1];
        NSArray *parts = [webSite componentsSeparatedByString:@"."];
        if(parts.count > 2) {
            NSMutableString *shortName = [NSMutableString stringWithString:parts[parts.count-2]];
            [shortName appendString:@"."];
            [shortName appendString:parts[parts.count-1]];
            webSite = shortName;
        }
        
        return webSite;
    }
    else {
        return email;
    }
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

- (BOOL)shouldUseWebSiteImage {
    return [[[[NSApplication sharedApplication] delegate] preferencesController] shouldUseServerContactImages];
}

- (NSImage*)loadAvatar:(NSString*)email completionBlock:(void (^)(NSImage*))completionBlock {
    NSString *webSite = [self webSiteFromEmail:email];

    NSImage *image = [_imageCache objectForKey:email];
    if(image == (NSImage*)[NSNull null]) {
        if(![self shouldUseWebSiteImage]) {
            return nil;
        }
        
        image = [_imageCache objectForKey:webSite];
        if(image == (NSImage*)[NSNull null]) {
            return nil;
        }
    }
    
    if(image != nil) {
        return image;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSImage *image = [self loadImageFromDisk:email];
        if(image != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_imageCache setObject:image forKey:email];
                completionBlock(image);
            });
        }
        else {
            NSString *emailMD5 = [self md5:email];
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@?d=404&size=%d", emailMD5, 128]];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLSession *session = [NSURLSession sharedSession];
            
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSImage *image = nil;
                if(error == nil && data != nil && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse*)response).statusCode == 200) {
                    image = [[NSImage alloc] initWithData:data];
                }
                
                if(image != nil) {
                    [self saveImageToDisk:email image:image];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    if(image != nil) {
                        [_imageCache setObject:image forKey:email];
                        completionBlock(image);
                    }
                    else {
                        [_imageCache setObject:(NSImage*)[NSNull null] forKey:email];

                        if(![self shouldUseWebSiteImage]) {
                            completionBlock(nil);
                            return;
                        }

                        [self loadWebSiteImage:webSite completionBlock:^(NSImage *image) {
                            if(image == nil) {
                                [_imageCache setObject:(NSImage*)[NSNull null] forKey:webSite];
                            }
                            else {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    [self saveImageToDisk:webSite image:image];
                                });

                                [_imageCache setObject:image forKey:webSite];
                            }
                            
                            completionBlock(image);
                        }];
                    }
                });
            }];
            
            [task resume];
        }
    });

    return nil;
}

- (void)loadWebSiteImage:(NSString*)webSite completionBlock:(void (^)(NSImage*))completionBlock {
    NSImage *image = [_imageCache objectForKey:webSite];
    if(image == (NSImage*)[NSNull null]) {
        completionBlock(nil);
        return;
    }
    else if(image != nil) {
        completionBlock(image);
        return;
    }
    
    image = [self loadImageFromDisk:webSite];
    if(image != nil) {
        completionBlock(image);
        return;
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
                page.webSite = webSite;
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
    }];

    [task resume];
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
//    if([webPage.baseURL.absoluteString isEqualToString:@"http://facebookmail.com"]) {
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
                    SM_LOG_INFO(@"web page: %@, found %@ image (%@, size %g x %g)", webPage.baseURL, perfectImageSize? @"perfect size" : @"largest available", response.URL, webPage.bestImage.size.width, webPage.bestImage.size.height);

                    for(NSURLSessionDataTask *t in webPage.imageDownloadTasks) {
                        [t cancel];
                    }
                    
                    void (^capturedCompletionBlock)(NSImage*) = webPage.completionBlock;
                    webPage.completionBlock = nil;

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(webPage.bestImage != nil) {
                            [_imageCache setObject:webPage.bestImage forKey:webPage.webSite];
                        }
                        else {
                            [_imageCache setObject:(NSImage*)[NSNull null] forKey:webPage.webSite];
                        }
                        
                        capturedCompletionBlock(webPage.bestImage);
                    });
                    
                    if(webPage.bestImage != nil) {
                        [self saveImageToDisk:webPage.webSite image:webPage.bestImage];
                    }
                    
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
