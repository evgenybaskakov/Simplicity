//
//  SMAddressFieldViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMSuggestionProvider.h"
#import "SMTokenField.h"
#import "SMLabeledTokenFieldBoxView.h"
#import "SMAddressListElement.h"
#import "SMAddressFieldViewController.h"

@implementation SMAddressFieldViewController {
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
    [(NSBox*)view setBorderColor:[NSColor lightGrayColor]];
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

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if (obj.object == _tokenField) {
        SM_LOG_DEBUG(@"obj.object: %@", obj);
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if (obj.object == _tokenField) {
        SM_LOG_DEBUG(@"obj.object: %@", obj);

        unsigned int whyEnd = [[[obj userInfo] objectForKey:@"NSTextMovement"] unsignedIntValue];
        
        if (whyEnd == NSTabTextMovement || whyEnd == NSReturnTextMovement) {
            NSWindow *window = [[self view] window];
            [window makeFirstResponder:_tokenField.nextKeyView];
        }
    }
}

#pragma mark Control switch

- (void)addControlSwitch:(NSInteger)state target:(id)target action:(SEL)action {
    NSAssert(_controlSwitch == nil, @"controlSwitch already exists");

    NSView *view = [self view];

    _controlSwitch = [[NSButton alloc] init];
    [_controlSwitch setButtonType:NSOnOffButton];
    [[_controlSwitch cell] setBezelStyle:NSDisclosureBezelStyle];
    _controlSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _controlSwitch.title = @"";
    _controlSwitch.state = state;
    _controlSwitch.target = target;
    _controlSwitch.action = action;

    [view addSubview:_controlSwitch];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_controlSwitch attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:5]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_controlSwitch attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_label attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_controlSwitch attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:_controlSwitch.intrinsicContentSize.width]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_controlSwitch attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:_controlSwitch.intrinsicContentSize.height]];
}

#pragma mark NSTokenFieldDelegate

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
//	SM_LOG_INFO(@"???");
	return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
//	SM_LOG_INFO(@"???");
	return NO;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
//	SM_LOG_INFO(@"???");
	return nil;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index {
	SM_LOG_DEBUG(@"%@", tokens);

    NSMutableArray *resultingObjects = [NSMutableArray array];
    
    for(id token in tokens) {
        if([token isKindOfClass:[SMAddressListElement class]]) {
            [resultingObjects addObject:token];
        }
        else {
            [resultingObjects addObject:[[SMAddressListElement alloc] initWithStringRepresentation:token]];
        }
    }

    return resultingObjects;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
    SM_LOG_DEBUG(@"substring: '%@', tokenIndex: %ld", substring, tokenIndex);
    
    return [_suggestionProvider suggestionsForPrefix:substring];
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
    SM_LOG_DEBUG(@"editingString: %@", editingString);
	return [[SMAddressListElement alloc] initWithStringRepresentation:editingString];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    SMAddressListElement *addressElem = representedObject;
	return [addressElem stringRepresentationShort];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LabeledTokenFieldEndedEditing" object:self userInfo:nil];
	return YES;
}

@end
