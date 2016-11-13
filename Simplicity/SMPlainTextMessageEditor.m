//
//  SMPlainTextMessageEditor.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMPlainTextMessageEditor.h"

@implementation SMPlainTextMessageEditor {
    NSMutableArray<NSValue*> *_highlightPositions;
    NSUInteger _markedOccurrenceIndex;
    NSColor *_highlightColor;
    NSString *_stringToFind;
}

- (id)initWithString:(NSString*)string {
    self = [super initWithFrame:NSMakeRect(0, 0, 100, 100)];

    if(self) {
        _highlightColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
        
        _textView = [[NSTextView alloc] initWithFrame:self.frame];
        _textView.automaticQuoteSubstitutionEnabled = NO;
        _textView.automaticDashSubstitutionEnabled = NO;
        _textView.automaticLinkDetectionEnabled = YES;
        _textView.delegate = self;
        _textView.richText = NO;
        _textView.allowsUndo = YES;
        _textView.verticallyResizable = YES;
        _textView.translatesAutoresizingMaskIntoConstraints = YES;
        _textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        if(string) {
            _textView.string = string;
        }

        self.borderType = NSNoBorder;
        self.translatesAutoresizingMaskIntoConstraints = YES;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.hasVerticalScroller = YES;
        self.documentView = _textView;

        [self setMessageFont];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultMessageFontChanged:) name:@"SMDefaultMessageFontChanged" object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)defaultMessageFontChanged:(NSNotification*)notification {
    [self setMessageFont];
}

- (void)setMessageFont {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    _textView.font = (preferencesController.useFixedSizeFontForPlainTextMessages? preferencesController.fixedMessageFont : preferencesController.regularMessageFont);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
    if (selector == @selector(insertBacktab:)) {
        [[textView window] selectPreviousKeyView:nil];
        return YES;
    }

    [_textView breakUndoCoalescing];

    return NO;
}

#pragma mark Content finding

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase {
    NSString *messageText = [_textView string];
    NSMutableAttributedString *attrText = [_textView textStorage];
    NSRange searchRange = NSMakeRange(0, messageText.length);
    
    [attrText beginEditing];
    
    [self removeAllHighlightedOccurrencesOfString];

    if(searchRange.length == 0) {
        [attrText endEditing];
        return;
    }
    
    BOOL searchOptions = (matchCase? 0 : NSCaseInsensitiveSearch);
    
    if(!_highlightPositions) {
        _highlightPositions = [NSMutableArray array];
    }
    [_highlightPositions removeAllObjects];
    
    while(TRUE) {
        NSRange r = [messageText rangeOfString:str options:searchOptions range:searchRange];
        
        if(r.location == NSNotFound) {
            break;
        }
        
        [attrText addAttribute:NSBackgroundColorAttributeName value:_highlightColor range:r];
        
        searchRange.location = r.location + 1;
        searchRange.length = messageText.length - r.location - 1;
        
        [_highlightPositions addObject:[NSValue valueWithRange:r]];
    }
    
    [attrText endEditing];
    
    _markedOccurrenceIndex = 0;
    _stringToFind = str;
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
    NSMutableAttributedString *attrText = [_textView textStorage];

    [attrText beginEditing];

    [self removeMarkedOccurrenceOfFoundString];
    
    if(index >= _highlightPositions.count) {
        [attrText endEditing];
        return;
    }
    
    NSRange r = [_highlightPositions[index] rangeValue];
    
    [attrText addAttribute:NSBackgroundColorAttributeName value:[NSColor yellowColor] range:r];
    [attrText endEditing];
    
    _markedOccurrenceIndex = index;
}

- (void)removeMarkedOccurrenceOfFoundString {
    if(_markedOccurrenceIndex >= _highlightPositions.count) {
        return;
    }
    
    NSMutableAttributedString *attrText = [_textView textStorage];
    NSRange r = [_highlightPositions[_markedOccurrenceIndex] rangeValue];
    
    [attrText addAttribute:NSBackgroundColorAttributeName value:_highlightColor range:r];
    
    _markedOccurrenceIndex = 0;
}

- (void)removeAllHighlightedOccurrencesOfString {
    NSString *messageText = [_textView string];
    NSMutableAttributedString *attrText = [_textView textStorage];

    [attrText removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(0, messageText.length)];
}

- (NSUInteger)stringOccurrencesCount {
    return _highlightPositions.count;
}

- (void)animatedScrollToMarkedOccurrence {
    if(_markedOccurrenceIndex >= _highlightPositions.count) {
        return;
    }
    
    [_textView scrollRangeToVisible:[_highlightPositions[_markedOccurrenceIndex] rangeValue]];
}

- (void)replaceOccurrence:(NSUInteger)index replacement:(NSString*)replacement {
    if(_markedOccurrenceIndex >= _highlightPositions.count) {
        return;
    }
    
    if([_stringToFind isEqualToString:replacement]) {
        return;
    }
    
    NSMutableAttributedString *attrText = [_textView textStorage];
    NSRange r = [_highlightPositions[index] rangeValue];

    [attrText beginEditing];
    [attrText removeAttribute:NSBackgroundColorAttributeName range:r];
    [attrText replaceCharactersInRange:r withString:replacement];
    [attrText endEditing];
    
    // TODO: update highlight positions
}

@end
