//
//  SMRoundedImageView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/16/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMRoundedImageView : NSImageView

@property (nonatomic) BOOL nonOriginalBehavior;
@property (nonatomic) BOOL scaleImage;
@property (nonatomic) NSUInteger cornerRadius;
@property (nonatomic) NSUInteger borderWidth;
@property (nonatomic) NSUInteger insetsWidth;
@property (nonatomic) NSColor *borderColor;

@end
