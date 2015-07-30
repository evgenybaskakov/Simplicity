//
//  SMLabeledTokenFieldBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMTokenField.h"
#import "SMLabeledTokenFieldBoxView.h"
#import "SMLabeledTokenFieldBoxViewController.h"

@implementation SMLabeledTokenFieldBoxViewController {
	Boolean _tokenFieldFrameValid;
}

- (void)viewDidLoad {
    [super viewDidLoad];

	NSView *view = [self view];

	NSAssert([view isKindOfClass:[NSBox class]], @"view not NSBox");
	NSAssert([view isKindOfClass:[SMLabeledTokenFieldBoxView class]], @"view not SMLabeledTokenFieldBoxView");
	
	[(SMLabeledTokenFieldBoxView*)view setViewController:self];

	[(NSBox*)view setBoxType:NSBoxCustom];
	[(NSBox*)view setTitlePosition:NSNoTitle];
	[(NSBox*)view setFillColor:[NSColor whiteColor]];
}

- (void)viewDidAppear {
	if(!_tokenFieldFrameValid) {
		// this is critical because the frame height for each SMTokenField must be
		// recalculated after its width is known, which happens when it is drawn
		// for the first time

		[_tokenField invalidateIntrinsicContentSize];

		_tokenFieldFrameValid = YES;
	}
}

- (NSSize)intrinsicContentViewSize {
	return NSMakeSize(-1, _tokenField.intrinsicContentSize.height + _topTokenFieldContraint.constant + _bottomTokenFieldContraint.constant);
}

- (void)invalidateIntrinsicContentViewSize {
	[[self view] setNeedsUpdateConstraints:YES];
}

#pragma mark Control switch

- (void)addControlSwitch:(NSInteger)state target:(id)target action:(SEL)action {
    NSAssert(_controlSwitch == nil, @"controlSwitch already exists");

    _controlSwitch = [[NSButton alloc] init];
    [_controlSwitch setButtonType:NSOnOffButton];
    [[_controlSwitch cell] setBezelStyle:NSDisclosureBezelStyle];
    _controlSwitch.title = @"";
    _controlSwitch.state = state;
    _controlSwitch.frame = NSMakeRect(0, 1, _controlSwitch.intrinsicContentSize.width, _controlSwitch.intrinsicContentSize.height);
    _controlSwitch.target = target;
    _controlSwitch.action = action;
    
    [[self view] addSubview:_controlSwitch];
}

#pragma mark NSTokenFieldDelegate

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
	//NSLog(@"%s", __func__);
	return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	//NSLog(@"%s", __func__);
	return NO;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
	//NSLog(@"%s", __func__);
	return nil;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index {
	//NSLog(@"%s", __func__);
	// TODO: scan address books for the recepient name and/or verify the email address for correctness
	return nil;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
	//NSLog(@"%s", __func__);
	// TODO: scan address books for the recepient name
	return nil;
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
	// TODO: append a recepient name from address books
	return editingString;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
	//NSLog(@"%s", __func__);
	return nil;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LabeledTokenFieldEndedEditing" object:self userInfo:nil];
	return YES;
}

@end
