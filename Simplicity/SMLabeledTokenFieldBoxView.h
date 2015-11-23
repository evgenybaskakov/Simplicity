//
//  SMLabeledTokenFieldBoxView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMAddressFieldViewController;

@interface SMLabeledTokenFieldBoxView : NSBox

- (void)setViewController:(SMAddressFieldViewController*)controller;

@end
