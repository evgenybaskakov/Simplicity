//
//  SMLabeledTokenFieldBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <AddressBook/AddressBook.h>

#import "SMLog.h"
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
	SM_LOG_DEBUG(@"???");
	return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	SM_LOG_DEBUG(@"???");
	return NO;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
	SM_LOG_DEBUG(@"???");
	return nil;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index {
	SM_LOG_INFO(@"%@", tokens);
	// TODO: scan address books for the recepient name and/or verify the email address for correctness
	return tokens;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
    SM_LOG_INFO(@"substring: '%@', tokenIndex: %ld", substring, tokenIndex);

    NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    
    [self searchAddressBookProperty:kABEmailProperty value:substring results:results];
    [self searchAddressBookProperty:kABFirstNameProperty value:substring results:results];
    [self searchAddressBookProperty:kABLastNameProperty value:substring results:results];
    
    return [results sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
        return [str1 compare:str2];
    }];
}

- (void)searchAddressBookProperty:(NSString*)property value:(NSString*)value results:(NSMutableOrderedSet*)results {
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [ABPerson searchElementForProperty:property label:nil key:nil value:value comparison:kABPrefixMatchCaseInsensitive];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];
    
    for(NSUInteger i = 0; i < foundRecords.count; i++) {
        ABRecord *record = foundRecords[i];
        ABMultiValue *emails = [record valueForProperty:kABEmailProperty];
        
        for(NSUInteger j = 0; j < emails.count; j++) {
            NSString *email = [emails valueAtIndex:j];
            [results addObject:email];
        }
    }
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
	// TODO: append a recepient name from address books
	return editingString;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
	SM_LOG_DEBUG(@"???");
	return nil;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LabeledTokenFieldEndedEditing" object:self userInfo:nil];
	return YES;
}

@end
