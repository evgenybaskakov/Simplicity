//
//  SMPlainTextMessageEditor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMPlainTextMessageEditor : NSScrollView

@property (readonly) NSTextView *textView;

- (id)initWithString:(NSString*)string;

@end
