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

@implementation SMPlainTextMessageEditor

- (id)initWithString:(NSString*)string {
    self = [super initWithFrame:NSMakeRect(0, 0, 100, 100)];
    
    if(self) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMPreferencesController *preferencesController = [appDelegate preferencesController];

        _textView = [[NSTextView alloc] initWithFrame:self.frame];
        _textView.delegate = self;
        _textView.richText = NO;
        _textView.verticallyResizable = YES;
        _textView.string = string;
        _textView.font = preferencesController.fixedMessageFont;
        _textView.translatesAutoresizingMaskIntoConstraints = YES;
        _textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        self.borderType = NSNoBorder;
        self.translatesAutoresizingMaskIntoConstraints = YES;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.documentView = _textView;
    }
    
    return self;
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
    
    return NO;
}

@end
