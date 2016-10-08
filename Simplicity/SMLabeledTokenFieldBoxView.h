//
//  SMLabeledTokenFieldBoxView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMAddressFieldViewController;

@interface SMLabeledTokenFieldBoxView : NSView

@property BOOL drawTopLine;
@property BOOL drawBottomLine;
@property CGFloat topLineOffset;
@property CGFloat bottomLineOffset;
@property NSColor *lineColor;

- (void)setViewController:(SMAddressFieldViewController*)controller;

@end
