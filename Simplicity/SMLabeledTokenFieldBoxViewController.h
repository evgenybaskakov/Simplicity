//
//  SMLabeledTokenFieldBoxViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMTokenField;

@interface SMLabeledTokenFieldBoxViewController : NSViewController<NSTokenFieldDelegate>

@property IBOutlet NSTextField *label;
@property IBOutlet SMTokenField *tokenField;

@property (readonly) NSButton *controlSwitch;

- (NSSize)intrinsicContentViewSize;
- (void)invalidateIntrinsicContentViewSize;
- (void)addControlSwitch:(NSInteger)state target:(id)target action:(SEL)action;

@end
