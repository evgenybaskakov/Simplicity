//
//  SMMessageViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/25/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <WebKit/WebView.h>
#import <WebKit/WebFrame.h>
#import <WebKit/WebFrameView.h>
#import <WebKit/WebDataSource.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebPolicyDelegate.h>
#import <WebKit/WebPreferences.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageBodyViewController.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMAttachmentStorage.h"

@interface SMMessageBodyViewController (WebResourceLoadDelegate)

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource;

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveContentLength:(NSUInteger)length fromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource;

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener;

@end

@interface SMMessageBodyViewController (WebFrameLoadDelegate)

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;

@end

@implementation SMMessageBodyViewController {
    SMUserAccount *_account;
    unsigned long long _nextIdentifier;
    NSString *_currentFindString;
    Boolean _currentFindStringMatchCase;
    NSString *_htmlText;
    uint32_t _uid;
    NSString *_folder;
    Boolean _uncollapsed;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        WebView *view = [[WebView alloc] init];
        
        view.translatesAutoresizingMaskIntoConstraints = NO;

        [view setUIDelegate:self];
        [view setFrameLoadDelegate:self];
        [view setPolicyDelegate:self];
        [view setResourceLoadDelegate:self];
        [view setMaintainsBackForwardList:NO];
        [view setCanDrawConcurrently:YES];
        [view setEditable:NO];
        
        [self setView:view];
        
        [self setDefaultFonts];
        
        _nextIdentifier = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultMessageFontChanged:) name:@"SMDefaultMessageFontChanged" object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)defaultMessageFontChanged:(NSNotification*)notification {
    [self setDefaultFonts];
}

- (void)setDefaultFonts {
    WebView *view = (WebView *)self.view;
    
    SMPreferencesController *preferencesController = [[[NSApplication sharedApplication] delegate] preferencesController];

    NSFont *regularFont = preferencesController.regularMessageFont;
    NSFont *fixedFont = preferencesController.fixedMessageFont;

    [[view preferences] setDefaultFontSize:(int)regularFont.pointSize];
    [[view preferences] setStandardFontFamily:regularFont.familyName];

    [[view preferences] setDefaultFixedFontSize:(int)fixedFont.pointSize];
    [[view preferences] setFixedFontFamily:fixedFont.familyName];
}

- (void)loadHTML {
    NSAssert(_uncollapsed, @"view is collapsed");

    WebView *view = (WebView*)[self view];
    [[view mainFrame] loadHTMLString:_htmlText baseURL:nil];
}

- (void)setMessageHtmlText:(NSString*)htmlText uid:(uint32_t)uid folder:(NSString*)folder account:(SMUserAccount*)account {
    _account = account;
    
    WebView *view = (WebView*)[self view];
    [view stopLoading:self];
    
    _htmlText = htmlText;
    _uid = uid;
    _folder = folder;
    
    if(_uncollapsed) {
        [self loadHTML];
    }
}

- (void)uncollapse {
    if(!_uncollapsed) {
        _uncollapsed = YES;
        [self loadHTML];
    }
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource {
//  SM_LOG_DEBUG(@"request %@, identifier %llu", request, _nextIdentifier);
    return [NSNumber numberWithUnsignedLongLong:_nextIdentifier++];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    
//  SM_LOG_DEBUG(@"request %@, identifier %@", request, identifier);
    
    NSURL *url = [request URL];
    NSString *absoluteUrl = [url absoluteString];
    
//  SM_LOG_DEBUG(@"url absoluteString: %@", absoluteUrl);
    
    ////
//  NSScrollView *scrollView = [[[[_view mainFrame] frameView] documentView] enclosingScrollView];
//  NSRect scrollViewBounds = [[scrollView contentView] bounds];
//  NSPoint savedScrollPosition = scrollViewBounds.origin;
//  NSSize savedScrollSize = scrollViewBounds.size;
//  SM_LOG_DEBUG(@"Current scroll position: %f, %f\n", savedScrollPosition.x, savedScrollPosition.y);
//  SM_LOG_DEBUG(@"Current scroll size: %f, %f\n", savedScrollSize.width, savedScrollSize.height);
    ////
    
    if([absoluteUrl hasPrefix:@"cid:"]) {
        // TODO: handle not completely downloaded attachments
        // TODO: implement a precise contentId matching (to handle the really existing imap parts)
        NSString *contentId = [absoluteUrl substringFromIndex:4];
        NSURL *attachmentLocation = [[_account attachmentStorage] attachmentLocation:contentId uid:_uid folder:_folder];
        
        if(!attachmentLocation) {
            SM_LOG_DEBUG(@"cannot load attachment for contentId %@", contentId);
            return request;
        }
        
//      SM_LOG_DEBUG(@"loading attachment file '%@' for contentId %@", attachmentLocation, contentId);
        return [NSURLRequest requestWithURL:attachmentLocation];
    }
    
    return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource {
//  SM_LOG_DEBUG(@"identifier %@", identifier);
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource {
//  SM_LOG_DEBUG(@"identifier %@", identifier);
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveContentLength:(NSUInteger)length fromDataSource:(WebDataSource *)dataSource {
//  SM_LOG_DEBUG(@"identifier %@", identifier);
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource {
//  SM_LOG_DEBUG(@"identifier %@", identifier);
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    if ([actionInformation objectForKey:WebActionElementKey]) {
        [listener ignore];
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    } else {
        [listener use];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

- (void)webView:(WebView *)webView decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
    SM_LOG_INFO(@"");
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if(_htmlText == nil)
        return;

    if(sender != nil && frame == sender.mainFrame) {
        //NSAssert(!_mainFrameLoaded, @"main frame already loaded");

        if(_mainFrameLoaded) {
            SM_LOG_WARNING(@"!!!!!!!!!!! main frame already loaded !!!!!!!!!!!");
            return;
        }

        _mainFrameLoaded = YES;
        
        // Don't allow message body scrolling.
        // Instead, the thread cell is responsible for setting its
        // content side to fit the whole message. The message thread
        // view is the one who scrolls. Inner scrolling must not be
        // enabled to avoid user annoyance.
        [frame.frameView setAllowsScrolling:NO];

        if(_currentFindString != nil && _uncollapsed) {
            [self highlightAllOccurrencesOfString:_currentFindString matchCase:_currentFindStringMatchCase];
        }

        // TODO: remove duplication, see SMMessageEditorWebView.contentHeight
        _contentHeight = [[[frame frameView] documentView] frame].size.height;

        [SMNotificationsController localNotifyMessageViewFrameLoaded:_uid account:_account];
    }
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
    NSMutableArray *updatedMenuItems = [NSMutableArray arrayWithArray:defaultMenuItems];

    for(NSUInteger i = defaultMenuItems.count; i > 0; i--) {
        NSMenuItem *item = updatedMenuItems[i-1];
        
        if([item.title isEqualToString:@"Reload"]) {
            [updatedMenuItems removeObjectAtIndex:i-1];
        }
    }
    
    return updatedMenuItems;
}

#pragma mark Finding contents

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase {
    _currentFindString = str;
    _currentFindStringMatchCase = matchCase;
    
    if(!_mainFrameLoaded)
        return;
    
    NSAssert(str != nil, @"str == nil");

    [self removeAllHighlightedOccurrencesOfString];

    if(str.length > 0) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"SearchWebView" ofType:@"js"];
        NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        WebView *view = (WebView*)[self view];
        [view stringByEvaluatingJavaScriptFromString:jsCode];
        
        NSString *startSearch = [NSString stringWithFormat:@"Simplicity_HighlightAllOccurrencesOfString('%@', %u)", str, matchCase? 1 : 0];
        [view stringByEvaluatingJavaScriptFromString:startSearch];
        
        NSString *occurrencesCount = [view stringByEvaluatingJavaScriptFromString:@"Simplicity_SearchResultCount"];
        _stringOccurrencesCount = [occurrencesCount integerValue];
    }
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
    WebView *view = (WebView*)[self view];

    NSString *doMark = [NSString stringWithFormat:@"Simplicity_MarkOccurrenceOfFoundString('%lu')", index];
    [view stringByEvaluatingJavaScriptFromString:doMark];
}

- (void)removeMarkedOccurrenceOfFoundString {
    WebView *view = (WebView*)[self view];
    [view stringByEvaluatingJavaScriptFromString:@"Simplicity_RemoveMarkedOccurrenceOfFoundString()"];
}

- (void)removeAllHighlightedOccurrencesOfString {
    WebView *view = (WebView*)[self view];
    [view stringByEvaluatingJavaScriptFromString:@"Simplicity_RemoveAllHighlights()"];
    
    _currentFindString = nil;
}

@end
