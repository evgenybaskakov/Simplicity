//
//  SMMessageBodyViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/31/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebPolicyDelegate.h>
#import <WebKit/WebFrameLoadDelegate.h>
#import <WebKit/WebResourceLoadDelegate.h>
#import <WebKit/WebUIDelegate.h>

@class WebView;

@class SMUserAccount;

@interface SMMessageBodyViewController : NSViewController<WebFrameLoadDelegate, WebPolicyDelegate, WebResourceLoadDelegate, WebUIDelegate>

@property (readonly) NSUInteger contentHeight;
@property (readonly) NSUInteger stringOccurrencesCount;
@property (readonly) Boolean mainFrameLoaded;

- (void)uncollapse;
- (void)setMessageHtmlText:(NSString*)htmlText messageId:(uint64_t)messageId folder:(NSString*)folder account:(SMUserAccount*)account;
- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase;
- (void)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;

@end
