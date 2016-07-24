//
//  SMBoxView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMBoxView : NSView

@property (nonatomic) NSColor *fillColor;
@property (nonatomic) NSColor *boxColor;
@property (nonatomic) NSColor *mouseInColor;
@property (nonatomic) BOOL drawTop;
@property (nonatomic) BOOL drawBottom;
@property (nonatomic) NSUInteger leftTopInset;
@property (nonatomic) NSUInteger leftBottomInset;
@property (nonatomic) BOOL trackMouse;

@end
