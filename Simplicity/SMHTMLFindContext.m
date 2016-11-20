//
//  SMHTMLFindContext.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "SMHTMLFindContext.h"

#define Simplicity_HighlightClass           @"Simplicity_Highlight"
#define Simplicity_HighlightColorText       @"black"
#define Simplicity_HighlightColorBackground @"lightgray"
#define Simplicity_MarkColorText            @"black"
#define Simplicity_MarkColorBackground      @"yellow"

@implementation SMHTMLFindContext {
    DOMDocument *_document;
    NSMutableArray<DOMElement*> *_searchResults;
}

- (id)initWithDocument:(DOMDocument*)document {
    self = [super init];
    
    if(self) {
        _searchResults = [NSMutableArray array];
        _document = document;
    }

    return self;
}

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    // TODO
    //    if(!_mainFrameLoaded)
    //        return;
    
    NSAssert(str != nil, @"str == nil");
    
    [self removeAllHighlightedOccurrencesOfString];
    
    if(str.length == 0) {
        return;
    }
    
    DOMHTMLElement *bodyElement = _document.body;
    
    [self highlightAllOccurrencesOfStringForElement:bodyElement str:(matchCase ? str : [str lowercaseString]) matchCase:matchCase];
    [self getOccurrencesCount];
    
    [_searchResults sortUsingComparator:^NSComparisonResult(DOMElement *a, DOMElement *b) {
        if(NSMaxY(b.boundingBox) != NSMaxY(a.boundingBox)) {
            return NSMaxY(b.boundingBox) - NSMaxY(a.boundingBox);
        }
        else {
            return NSMinX(b.boundingBox) - NSMinX(a.boundingBox);
        }
    }];
}

- (BOOL)elementVisible:(DOMElement*)element {
    return element.offsetWidth > 0 || element.offsetHeight > 0;
}

- (void)highlightAllOccurrencesOfStringForElement:(DOMNode*)element str:(NSString*)str matchCase:(BOOL)matchCase {
    if(!element) {
        return;
    }

    if(element.nodeType == DOM_TEXT_NODE) {
        while (true) {
            NSString *value = element.nodeValue;
            NSRange r = matchCase? [value rangeOfString:str] : [[value lowercaseString] rangeOfString:str];
            
            if(r.location == NSNotFound) {
                break;
            }
            
            DOMElement *span = [_document createElement:@"span"];
            DOMText *text = [_document createTextNode:[value substringWithRange:r]];
            
            [span appendChild:text];
            [span setAttribute:@"class" value:Simplicity_HighlightClass];
            
            span.style.backgroundColor = Simplicity_HighlightColorBackground;
            span.style.color = Simplicity_HighlightColorText;
            
            text = [_document createTextNode:[value substringFromIndex:r.location + str.length]];
            
            [element setNodeValue:[value substringToIndex:r.location]];
            
            DOMNode *next = element.nextSibling;
            
            [element.parentNode insertBefore:span refChild:next];
            [element.parentNode insertBefore:text refChild:next];
            
            element = text;
            
            if([self elementVisible:span]) {
                [_searchResults addObject:span];
            }
        }
    }
    else if(element.nodeType == DOM_ELEMENT_NODE && [element isKindOfClass:[DOMHTMLElement class]]) {
        DOMHTMLElement *htmlElement = (DOMHTMLElement*)element;
        
        if(![htmlElement.style.display isEqualToString:@"none"] && ![[htmlElement.nodeName lowercaseString] isEqualToString:@"select"]) {
            DOMNodeList *childNodes = htmlElement.childNodes;
            
            for (unsigned i = childNodes.length; i != 0; i--) {
                DOMNode *child = [childNodes item:i-1];
                
                [self highlightAllOccurrencesOfStringForElement:child str:str matchCase:matchCase];
            }
        }
    }
}

- (BOOL)removeAllHighlightsForElement:(DOMNode*)element {
    if(!element || element.nodeType != DOM_ELEMENT_NODE) {
        return false;
    }
    
    if([[[element.attributes getNamedItem:@"class"] nodeValue] isEqualToString:Simplicity_HighlightClass]) {
        DOMNode *text = [element removeChild:element.firstChild];
        
        [element.parentNode insertBefore:text refChild:element];
        [element.parentNode removeChild:element];
        
        return true;
    }
    else {
        DOMNodeList *childNodes = element.childNodes;
        BOOL normalize = NO;
        
        for (unsigned i = childNodes.length; i != 0; i--) {
            DOMNode *child = [childNodes item:i-1];
            
            if([self removeAllHighlightsForElement:child]) {
                normalize = YES;
            }
        }
        
        if(normalize) {
            [element normalize];
        }

        return false;
    }
}

- (void)getOccurrencesCount {
    _stringOccurrencesCount = _searchResults.count;
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
    [self removeMarkedOccurrenceOfFoundString];
    
    if(index >= _searchResults.count) {
        return;
    }
    
    DOMElement *span = _searchResults[_searchResults.count - index - 1];
    
    span.style.backgroundColor = Simplicity_MarkColorBackground;
    span.style.color = Simplicity_MarkColorText;
    
    _markedResultIndex = index;
    _markedOccurrenceYpos = NSMaxY(span.boundingBox);
}

- (void)removeMarkedOccurrenceOfFoundString {
    NSUInteger index = _markedResultIndex;
    
    if(index < _searchResults.count) {
        DOMElement *span = _searchResults[_searchResults.count - index - 1];
        
        span.style.backgroundColor = Simplicity_HighlightColorBackground;
        span.style.color = Simplicity_HighlightColorText;
    }
}

- (void)removeAllHighlightedOccurrencesOfString {
    DOMHTMLElement *bodyElement = _document.body;
    [self removeAllHighlightsForElement:bodyElement];
    
    [_searchResults removeAllObjects];
}

#pragma mark Replacing content

- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement {
    if(index >= _searchResults.count) {
        return;
    }
    
    DOMElement *span = _searchResults[_searchResults.count - index - 1];
    DOMNode *text = [span removeChild:span.firstChild];
    
    text.nodeValue = replacement;
    
    [span.parentNode insertBefore:text refChild:span];
    [span.parentNode removeChild:span];
    
    [_searchResults removeObjectAtIndex:_searchResults.count - index - 1];
}

- (void)replaceAllOccurrences:(NSString*)replacement {
    for (NSUInteger i = 0; i < _searchResults.count; i++) {
        DOMElement *span = _searchResults[i];
        
        span.firstChild.nodeValue = replacement;
    }
    
    [self removeAllHighlightedOccurrencesOfString];
}

@end
