//
//  SMAddressFieldViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMSuggestionProvider.h"
#import "SMLabeledTokenFieldBoxView.h"

@class SMTokenField;

@interface SMAddressFieldViewController : NSViewController<NSTokenFieldDelegate>

@property (strong) IBOutlet SMLabeledTokenFieldBoxView *mainView;

@property IBOutlet NSTextField *label;
@property IBOutlet SMTokenField *tokenField;
@property IBOutlet NSLayoutConstraint *topTokenFieldContraint;
@property IBOutlet NSLayoutConstraint *bottomTokenFieldContraint;

@property (readonly) NSButton *controlSwitch;

@property (weak) id<SMSuggestionProvider> suggestionProvider;

- (NSSize)intrinsicContentViewSize;
- (void)invalidateIntrinsicContentViewSize;
- (void)addControlSwitch:(NSInteger)state target:(id)target action:(SEL)action;

@end
