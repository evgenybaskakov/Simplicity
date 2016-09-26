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

@end
