//
//  SMPlainTextMessageEditor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMPlainTextMessageEditor : NSScrollView<NSTextViewDelegate>

@property (readonly) NSTextView *textView;
@property (readonly) NSUInteger stringOccurrencesCount;

- (id)initWithString:(NSString*)string;

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase;
- (void)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;
- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement;
- (void)animatedScrollToMarkedOccurrence;

@end
