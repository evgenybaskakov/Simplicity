//
//  SMHTMLFindContext.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMHTMLFindContext : NSObject

@property (readonly) NSString *currentFindString;
@property (readonly) CGFloat markedOccurrenceYpos;
@property (readonly) NSUInteger markedResultIndex;
@property (readonly) NSUInteger stringOccurrencesCount;

- (id)initWithDocument:(DOMDocument*)document;

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase;
- (void)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;

@end
