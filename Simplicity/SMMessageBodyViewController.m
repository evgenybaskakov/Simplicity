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
#import <WebKit/WebScriptObject.h>

#import <WebKit/DOMDocument.h>
#import <WebKit/DOMElement.h>
#import <WebKit/DOMNode.h>
#import <WebKit/DOMNodeList.h>
#import <WebKit/DOMText.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageBodyViewController.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMAttachmentStorage.h"
#import "SMHTMLFindContext.h"

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
    BOOL _currentFindStringMatchCase;
    SMHTMLFindContext *_findContext;
    NSString *_htmlText;
    uint32_t _uid;
    uint64_t _messageId;
    NSString *_folder;
    BOOL _uncollapsed;
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
    WebView *view = (WebView*)self.view;
    
    [view setUIDelegate:nil];
    [view setFrameLoadDelegate:nil];
    [view setPolicyDelegate:nil];
    [view setResourceLoadDelegate:nil];

    [view stopLoading:self];
      
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)defaultMessageFontChanged:(NSNotification*)notification {
    [self setDefaultFonts];
}

- (void)setDefaultFonts {
    WebView *view = (WebView *)self.view;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];

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

- (void)setMessageHtmlText:(NSString*)htmlText messageId:(uint64_t)messageId folder:(NSString*)folder account:(SMUserAccount*)account {
    _account = account;
    
    WebView *view = (WebView*)[self view];
    [view stopLoading:self];
    
    _htmlText = htmlText;
    _messageId = messageId;
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
    NSURL *url = [request URL];
    NSString *absoluteUrl = [url absoluteString];
    
    if([absoluteUrl hasPrefix:@"cid:"]) {
        // TODO: handle not completely downloaded attachments
        // TODO: implement a precise contentId matching (to handle the really existing imap parts)
        NSString *contentId = [[absoluteUrl substringFromIndex:4] stringByRemovingPercentEncoding];
        NSURL *attachmentLocation = [[_account attachmentStorage] attachmentLocation:contentId uid:_uid folder:_folder];
        
        if(!attachmentLocation) {
            SM_LOG_DEBUG(@"cannot load attachment for contentId %@", contentId);
            return request;
        }
        
        SM_LOG_INFO(@"loading attachment file '%@' for contentId %@", attachmentLocation, contentId);
        
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

/*
        CGFloat scale = 0.8; // the scale factor that works for you
        NSString *jScript = [NSString stringWithFormat:@"document.body.style.zoom = %f;",scale];
        //@"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        
 */
        WebView *view = (WebView*)[self view];
/*
        WebScriptObject *scriptObject = [view windowScriptObject];
        [scriptObject evaluateWebScript:jScript];
*/
        
//        [[[[[[view mainFrame] frameView] documentView] scale] superview] scaleUnitSquareToSize:NSMakeSize(.5, .5)];
/*
        NSString *script = @"document.body.style.zoom";
        float oldFac = [[view stringByEvaluatingJavaScriptFromString:script] floatValue];
        if( oldFac==0 ){ oldFac = 1.0; }
        NSString *res = [view stringByEvaluatingJavaScriptFromString:
                         [NSString stringWithFormat:@"%@='%1.2f';", script, (oldFac*0.5)]];
        [view setNeedsDisplay:YES];
*/
        
        {
            DOMDocument* domDocument = [view mainFrameDocument];
            DOMElement* styleElement = [domDocument createElement:@"style"];
            [styleElement setAttribute:@"type" value:@"text/css"];
            DOMText* cssText = [domDocument createTextNode:@"img { max-width: 100%; }"];
            [styleElement appendChild:cssText];
            DOMElement* headElement = (DOMElement*)[[domDocument getElementsByTagName:@"head"] item:0];
            [headElement appendChild:styleElement];
        }
        _mainFrameLoaded = YES;
        _findContext = nil;
        
        // Don't allow message body scrolling.
        // Instead, the thread cell is responsible for setting its
        // content side to fit the whole message. The message thread
        // view is the one who scrolls. Inner scrolling must not be
        // enabled to avoid user annoyance.
        [frame.frameView setAllowsScrolling:NO];

        if(_currentFindString != nil && _uncollapsed) {
            [self highlightAllOccurrencesOfString:_currentFindString matchCase:_currentFindStringMatchCase];
        }

        // TODO: remove duplication, see SMMessageEditorView.contentHeight
        _contentHeight = [[[frame frameView] documentView] frame].size.height;

        [SMNotificationsController localNotifyMessageViewFrameLoaded:_messageId account:_account];
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

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    _currentFindString = str;
    _currentFindStringMatchCase = matchCase;
    
    if(!_mainFrameLoaded)
        return;
    
    NSAssert(str != nil, @"str == nil");

    [self removeAllHighlightedOccurrencesOfString];

    if(str.length == 0) {
        return;
    }
    
    WebView *view = (WebView*)[self view];

    if(!_findContext) {
        _findContext = [[SMHTMLFindContext alloc] initWithDocument:view.mainFrameDocument webview:view];
    }

    [_findContext highlightAllOccurrencesOfString:str matchCase:matchCase];
}

- (NSInteger)markOccurrenceOfFoundString:(NSUInteger)index {
    [_findContext markOccurrenceOfFoundString:index];
    return _findContext.markedOccurrenceYpos;
}

- (NSUInteger)stringOccurrencesCount {
    return _findContext.stringOccurrencesCount;
}

- (void)removeMarkedOccurrenceOfFoundString {
    [_findContext removeMarkedOccurrenceOfFoundString];
}

- (void)removeAllHighlightedOccurrencesOfString {
    [_findContext removeAllHighlightedOccurrencesOfString];
    _currentFindString = nil;
}

@end
