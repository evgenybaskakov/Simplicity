//
//  SMMessageEditorWebView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageEditorBase.h"
#import "SMMessageEditorWebView.h"

@implementation SMMessageEditorWebView {
    NSTimer *_textMonitorTimer;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self setFrameLoadDelegate:self];
    [self setPolicyDelegate:self];
    [self setResourceLoadDelegate:self];
    [self setEditingDelegate:self];
    [self setCanDrawConcurrently:YES];
    [self setEditable:YES];
    
    // Timer
    
    _textMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(textMonitorEvent:) userInfo:nil repeats:YES];
    
    // Editor
    
    [self startEditor];
}

- (void)startEditor {
    [self.mainFrame loadHTMLString:[SMMessageEditorBase newMessageHTMLTemplate] baseURL:nil];
}

- (void)stopTextMonitor {
    [_textMonitorTimer invalidate];    
    _textMonitorTimer = nil;
}

- (NSString*)getFontTypeface:(NSInteger)index {
    if(index < 0 || index >= [SMMessageEditorBase fontNames].count) {
        return nil;
    }
    
    return [SMMessageEditorBase fontNames][index];
}

- (NSString*)getMessageText {
    return [(DOMHTMLElement *)[[self.mainFrame DOMDocument] documentElement] outerHTML];
}

#pragma mark Content queries and modifications

- (void)toggleBold {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Bold')"];
}

- (void)toggleItalic {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Italic')"];
}

- (void)toggleUnderline {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('Underline')"];
}

- (void)toggleBullets {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertUnorderedList')"];
}

- (void)toggleNumbering {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('insertOrderedList')"];
}

- (void)toggleQuote {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('formatBlock', false, 'blockquote')"];
}

- (void)shiftLeft {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('outdent')"];
}

- (void)shiftRight {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand('indent')"];
}

- (void)selectFont:(NSInteger)index {
    NSString *fontName = [self getFontTypeface:index];
    
    if(fontName != nil) {
        [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontName', false, '%@')", fontName]];
    } else {
        NSLog(@"%s: no selected font", __func__);
    }
}

- (void)setTextSize:(NSInteger)textSize {
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('fontSize', false, %ld)", textSize]];
}

- (void)justifyText:(NSInteger)index {    
    NSString *justifyFunc = nil;
    
    switch(index) {
        case 0: justifyFunc = @"justifyLeft"; break;
        case 1: justifyFunc = @"justifyCenter"; break;
        case 2: justifyFunc = @"justifyFull"; break;
        case 3: justifyFunc = @"justifyRight"; break;
        default: NSAssert(nil, @"Unexpected index %ld", index);
    }
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('%@', false)", justifyFunc]];
}

- (NSString*)colorToHex:(NSColor*)color {
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(color.redComponent * 0xFF), (int)(color.greenComponent * 0xFF), (int)(color.blueComponent * 0xFF)];
}

- (void)setTextForegroundColor:(NSColor*)color {
    NSString *hexString = [self colorToHex:color];
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('foreColor', false, '%@')", hexString]];
}

- (void)setTextBackgroundColor:(NSColor*)color {
    NSString *hexString = [self colorToHex:color];
    
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand('backColor', false, '%@')", hexString]];
}

- (void)showSource {
    NSString *messageText = [self getMessageText];
    
    NSLog(@"%@", messageText);
}

@end
