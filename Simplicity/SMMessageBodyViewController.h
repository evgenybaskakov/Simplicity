//
//  SMMessageBodyViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/31/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView;

@interface SMMessageBodyViewController : NSViewController

@property (readonly) NSUInteger contentHeight;
@property (readonly) NSUInteger stringOccurrencesCount;
@property (readonly) Boolean mainFrameLoaded;

- (void)uncollapse;
- (void)setMessageHtmlText:(NSString*)htmlText uid:(uint32_t)uid folder:(NSString*)folder;
- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase;
- (void)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;

@end
