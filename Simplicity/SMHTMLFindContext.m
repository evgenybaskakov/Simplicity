//
//  SMHTMLFindContext.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "SMLog.h"
#import "SMHTMLFindContext.h"

#define Simplicity_HighlightClass           @"Simplicity_Highlight"
#define Simplicity_HighlightColorText       @"black"
#define Simplicity_HighlightColorBackground @"lightgray"
#define Simplicity_MarkColorText            @"black"
#define Simplicity_MarkColorBackground      @"yellow"

@implementation SMHTMLFindContext {
    DOMDocument *_document;
    NSString *_stringToFind;
    NSString *_replacementString;
    BOOL _matchCase;
    NSMutableArray<DOMElement*> *_searchResults;
    WebView *_webview;
}

- (id)initWithDocument:(DOMDocument*)document webview:(WebView*)webview {
    self = [super init];
    
    if(self) {
        _searchResults = [NSMutableArray array];
        _document = document;
        _webview = webview;
    }

    return self;
}

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    NSAssert(str != nil, @"str == nil");
    
    [self removeAllHighlightedOccurrencesOfString];
    
    if(str.length == 0) {
        return;
    }
    
    _matchCase = matchCase;
    _stringToFind = matchCase ? str : str.lowercaseString;
    
    [self highlightAllOccurrencesOfStringForElement:_document.body];
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

- (void)highlightAllOccurrencesOfStringForElement:(DOMNode*)element {
    if(!element) {
        return;
    }

    if(element.nodeType == DOM_TEXT_NODE) {
        while (true) {
            NSString *value = element.nodeValue;
            NSRange r = _matchCase? [value rangeOfString:_stringToFind] : [[value lowercaseString] rangeOfString:_stringToFind];
            
            if(r.location == NSNotFound) {
                break;
            }
            
            DOMElement *span = [_document createElement:@"span"];
            DOMText *text = [_document createTextNode:[value substringWithRange:r]];
            
            [span appendChild:text];
            [span setAttribute:@"class" value:Simplicity_HighlightClass];
            
            span.style.backgroundColor = Simplicity_HighlightColorBackground;
            span.style.color = Simplicity_HighlightColorText;
            
            text = [_document createTextNode:[value substringFromIndex:r.location + _stringToFind.length]];
            
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
                [self highlightAllOccurrencesOfStringForElement:[childNodes item:i-1]];
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
        NSString *textValue = text.nodeValue;
        DOMNode *leftSibling = element.previousSibling;
        NSString *siblingValue = leftSibling.nodeValue;
        
        [leftSibling setNodeValue:[siblingValue stringByAppendingString:textValue]];
        [element.parentNode removeChild:element];
        
        return true;
    }
    else {
        DOMNodeList *childNodes = element.childNodes;
        BOOL normalize = NO;
        
        for (unsigned i = childNodes.length; i != 0; i--) {
            if([self removeAllHighlightsForElement:[childNodes item:i-1]]) {
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
    [self removeAllHighlightsForElement:_document.body];
    
    [_searchResults removeAllObjects];
}

#pragma mark Replacing content

- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement {
    if(index >= _searchResults.count) {
        return;
    }
    
    _replacementString = replacement;
    
    DOMElement *span = _searchResults[_searchResults.count - index - 1];
    DOMNode *text = span.firstChild;
    NSString *textValue = text.nodeValue;
    NSUInteger textLen = textValue.length;
    DOMNode *orig = span.previousSibling;
    
    // Go to the beginning of the text where the replacement has been done and count the full length.
    NSUInteger prefixLen = orig.nodeValue.length;
    while(orig.previousSibling && [[[orig.previousSibling.attributes getNamedItem:@"class"] nodeValue] isEqualToString:Simplicity_HighlightClass]) {
        orig = orig.previousSibling.previousSibling;
        prefixLen += orig.nodeValue.length + textLen;
    }
    
    [_searchResults removeObjectAtIndex:_searchResults.count - index - 1];

    if(_replacementString.length != 0) {
        [self removeAllHighlightedOccurrencesOfString];
      
        DOMRange *range = [[[_webview mainFrame] DOMDocument] createRange];
        [range setStart:orig offset:(int)prefixLen];
        [range setEnd:orig offset:(int)(prefixLen + textLen)];

        [_webview setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
        [_webview replaceSelectionWithText:_replacementString];

        DOMRange *emptyRange = [[[_webview mainFrame] DOMDocument] createRange];
        [_webview setSelectedDOMRange:emptyRange affinity:NSSelectionAffinityDownstream];

        [self highlightAllOccurrencesOfString:textValue matchCase:_matchCase];
    }

    _replacementString = nil;
}

- (void)replaceAllOccurrencesForElement:(DOMNode*)element {
    if(!element) {
        return;
    }
    
    if(element.nodeType == DOM_TEXT_NODE) {
        NSString *origValue = element.nodeValue;
        NSString *replacementValue = [origValue stringByReplacingOccurrencesOfString:_stringToFind withString:_replacementString options:(_matchCase? NSLiteralSearch : NSCaseInsensitiveSearch) range:NSMakeRange(0, origValue.length)];
        
        if(![origValue isEqualToString:replacementValue]) {
            DOMRange *range = [[[_webview mainFrame] DOMDocument] createRange];
            [range setStart:element offset:0];
            [range setEnd:element offset:(int)origValue.length];
            
            [_webview setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
            [_webview replaceSelectionWithText:replacementValue];
        }
    }
    else if(element.nodeType == DOM_ELEMENT_NODE && [element isKindOfClass:[DOMHTMLElement class]]) {
        DOMHTMLElement *htmlElement = (DOMHTMLElement*)element;
        
        if(![htmlElement.style.display isEqualToString:@"none"] && ![[htmlElement.nodeName lowercaseString] isEqualToString:@"select"]) {
            DOMNodeList *childNodes = htmlElement.childNodes;
            
            for (unsigned i = childNodes.length; i != 0; i--) {
                [self replaceAllOccurrencesForElement:[childNodes item:i-1]];
            }
        }
    }
}

- (void)replaceAllOccurrences:(NSString*)replacement {
    [self removeAllHighlightedOccurrencesOfString];
    
    _replacementString = replacement;

    [[_webview undoManager] beginUndoGrouping];
    
    [self replaceAllOccurrencesForElement:_document.body];

    DOMRange *emptyRange = [[[_webview mainFrame] DOMDocument] createRange];
    [_webview setSelectedDOMRange:emptyRange affinity:NSSelectionAffinityDownstream];
    [_webview replaceSelectionWithText:@""];

    [[_webview undoManager] endUndoGrouping];

    _replacementString = nil;
}

@end
