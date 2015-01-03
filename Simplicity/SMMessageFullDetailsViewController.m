//
//  SMMessageFullDetailsViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMTokenField.h"
#import "SMMessage.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageFullDetailsView.h"
#import "SMMessageFullDetailsViewController.h"

@implementation SMMessageFullDetailsViewController {
	NSTextField *_toLabel;
	NSTokenField *_toAddresses;
	NSTextField *_ccLabel;
	NSTokenField *_ccAddresses;
	Boolean _addressListsFramesValid;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		_addressListsFramesValid = NO;
		
		SMMessageFullDetailsView *view = [[SMMessageFullDetailsView alloc] init];
		view.translatesAutoresizingMaskIntoConstraints = NO;

		[view setViewController:self];
		[self setView:view];
		[self createSubviews];
	}
	
	return self;
}

#define V_GAP 10
#define V_GAP_HALF (V_GAP/2)

- (void)createSubviews {
	NSView *view = [self view];
	
	// init 'to' label
	
	_toLabel = [SMMessageDetailsViewController createLabel:@"To:" bold:NO];
	_toLabel.textColor = [NSColor blackColor];
	
	[view addSubview:_toLabel];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
	
	// init 'to' address list
	
	_toAddresses = [[SMTokenField alloc] init];
	_toAddresses.delegate = self; // TODO: reference loop here?
	_toAddresses.tokenStyle = NSPlainTextTokenStyle;
	_toAddresses.translatesAutoresizingMaskIntoConstraints = NO;
	[_toAddresses setBordered:NO];
	[_toAddresses setDrawsBackground:NO];
	
	[view addSubview:_toAddresses];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_toLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_toLabel.frame.size.width]];
	
	// init 'cc' label
	
	_ccLabel = [SMMessageDetailsViewController createLabel:@"Cc:" bold:NO];
	_ccLabel.textColor = [NSColor blackColor];
	
	[view addSubview:_ccLabel];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_toAddresses attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
	
	// init 'cc' address list
	
	_ccAddresses = [[SMTokenField alloc] init];
	_ccAddresses.delegate = self; // TODO: reference loop here?
	_ccAddresses.tokenStyle = NSPlainTextTokenStyle;
	_ccAddresses.translatesAutoresizingMaskIntoConstraints = NO;
	[_ccAddresses setBordered:NO];
	[_ccAddresses setDrawsBackground:NO];
	
	[view addSubview:_ccAddresses];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_ccLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_toAddresses attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_ccLabel.frame.size.width]];
}

- (void)setMessageDetails:(SMMessage*)message {
	NSArray *toAddressArray = [message.header to];
	NSMutableArray *newToArray = [[NSMutableArray alloc] initWithCapacity:toAddressArray.count];
	
	for(NSUInteger i = 0; i < toAddressArray.count; i++)
		newToArray[i] = [SMMessage parseAddress:toAddressArray[i]];
	
	[_toAddresses setObjectValue:newToArray];
	
	NSArray *ccAddressArray = [message.header cc];
	NSMutableArray *newCcArray = [[NSMutableArray alloc] initWithCapacity:ccAddressArray.count];
	
	for(NSUInteger i = 0; i < ccAddressArray.count; i++)
		newCcArray[i] = [SMMessage parseAddress:ccAddressArray[i]];
	
	[_ccAddresses setObjectValue:newCcArray];
	
	_addressListsFramesValid = NO;
}

- (void)viewDidAppear {
	if(!_addressListsFramesValid) {
		// this is critical because the frame height for each SMTokenField must be
		// recalculated after its width is known, which happens when it is drawn
		// for the first time
		
		[_toAddresses invalidateIntrinsicContentSize];
		[_ccAddresses invalidateIntrinsicContentSize];
		
		_addressListsFramesValid = YES;
	}
}

- (NSSize)intrinsicContentViewSize {
	return NSMakeSize(-1, [_toAddresses intrinsicContentSize].height + V_GAP_HALF + [_ccAddresses intrinsicContentSize].height);
}

- (void)invalidateIntrinsicContentViewSize {
	[[self view] setNeedsUpdateConstraints:YES];
}

#pragma mark - NSTokenFieldDelegate

// ---------------------------------------------------------------------------
//	styleForRepresentedObject:representedObject
//
//	Make sure our tokens are rounded.
//	The delegate should return:
//		NSDefaultTokenStyle, NSPlainTextTokenStyle or NSRoundedTokenStyle.
// ---------------------------------------------------------------------------
- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
	//	NSLog(@"%s", __func__);
	return NSRoundedTokenStyle;
}

// ---------------------------------------------------------------------------
//	hasMenuForRepresentedObject:representedObject
//
//	Make sure our tokens have a menu. By default tokens have no menus.
// ---------------------------------------------------------------------------
- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject
{
	//	NSLog(@"%s", __func__);
	return NO;
}

// ---------------------------------------------------------------------------
//	menuForRepresentedObject:representedObject
//
//	User clicked on a token, return the menu we want to represent for our token.
//	By default tokens have no menus.
// ---------------------------------------------------------------------------
- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject
{
	NSLog(@"%s", __func__);
	return nil;
}

// ---------------------------------------------------------------------------
//	shouldAddObjects:tokens:index
//
//	Delegate method to decide whether the given token list should be allowed,
//	we can selectively add/remove any token we want.
//
//	The delegate can return the array unchanged or return a modified array of tokens.
//	To reject the add completely, return an empty array.  Returning nil causes an error.
// ---------------------------------------------------------------------------
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
	NSLog(@"%s", __func__);
	return nil;
	/*
	 NSMutableArray *newArray = [NSMutableArray arrayWithArray:tokens];
	 
	 id aToken;
	 for (aToken in newArray)
	 {
		if ([[aToken description] isEqualToString:self.tokenTitleToAdd])
		{
	 MyToken *token = [[MyToken alloc] init];
	 token.name = [aToken description];
	 [newArray replaceObjectAtIndex:index withObject:token];
	 break;
		}
	 }
	 
	 return newArray;
	 */
}

// ---------------------------------------------------------------------------
//	completionsForSubstring:substring:tokenIndex:selectedIndex
//
//	Called 1st, and again every time a completion delay finishes.
//
//	substring =		the partial string that to be completed.
//	tokenIndex =	the index of the token being edited.
//	selectedIndex = allows you to return by-reference an index in the array
//					specifying which of the completions should be initially selected.
// ---------------------------------------------------------------------------
- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex
	indexOfSelectedItem:(NSInteger *)selectedIndex
{
	NSLog(@"%s", __func__);
	return nil;
}

// ---------------------------------------------------------------------------
//	representedObjectForEditingString:editingString
//
//	Called 2nd, after you choose a choice from the menu list and press return.
//
//	The represented object must implement the NSCoding protocol.
//	If your application uses some object other than an NSString for their represented objects,
//	you should return a new instance of that object from this method.
//
// ---------------------------------------------------------------------------
- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	NSLog(@"%s", __func__);
	return @"Wilma";
}

// ---------------------------------------------------------------------------
//	displayStringForRepresentedObject:representedObject
//
//	Called 3rd, once the token is ready to be displayed.
//
//	If you return nil or do not implement this method, then representedObject
//	is displayed as the string. The represented object must implement the NSCoding protocol.
// ---------------------------------------------------------------------------
- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	//	NSLog(@"%s", __func__);
	return representedObject;
}

@end
