//
//  SMAddressFieldViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMAddressBookController.h"
#import "SMSuggestionProvider.h"
#import "SMTokenField.h"
#import "SMLabeledTokenFieldBoxView.h"
#import "SMAddress.h"
#import "SMAddressFieldViewController.h"

@implementation SMAddressFieldViewController {
	Boolean _tokenFieldFrameValid;
    SMAddress *_addressWithMenu;
    NSArray *_nonEditedAddresses;
    NSString *_addressWithMenuUniqueId;
    NSUInteger _addressCountWhenEditStarted;
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

        _nonEditedAddresses = nil;
        
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

- (BOOL)editedAddress:(id)representedObject {
    if(_nonEditedAddresses == nil || [_nonEditedAddresses containsObject:representedObject]) {
        return NO;
    }
    else {
        return YES;
    }
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    if([self editedAddress:representedObject]) {
        return NSTokenStyleNone;
    }
    else {
        return NSTokenStyleRounded;
    }
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	return YES;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    SM_LOG_INFO(@"representeObject: %@", representedObject);

    NSMenu *menu = [[NSMenu alloc] init];
    
    [menu addItemWithTitle:@"Copy address" action:@selector(copyAddressAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Edit address" action:@selector(editAddressAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Remove address" action:@selector(removeAddressAction:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];

    NSString *addressUniqueId = nil;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[[appDelegate model] addressBookController] findAddress:representedObject uniqueId:&addressUniqueId]) {
        [menu addItemWithTitle:@"Open in address book" action:@selector(openInAddressBookAction:) keyEquivalent:@""];
    }
    else {
        [menu addItemWithTitle:@"Add to address book" action:@selector(addToAddressBookAction:) keyEquivalent:@""];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"New message" action:@selector(newMessageAction:) keyEquivalent:@""];
    
    _addressWithMenu = representedObject;
    _addressWithMenuUniqueId = addressUniqueId;
    _nonEditedAddresses = nil;
    
    return menu;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index {
	SM_LOG_INFO(@"???");

    NSMutableArray *resultingObjects = [NSMutableArray array];
    
    for(id token in tokens) {
        SMAddress *address = nil;
        
        if([token isKindOfClass:[SMAddress class]]) {
            address = token;
        }
        else {
            address = [[SMAddress alloc] initWithStringRepresentation:token];
        }

        if(_addressCountWhenEditStarted > 0) {
            _addressCountWhenEditStarted--;
            SM_LOG_INFO(@"_addressCountWhenEditStarted->%lu",_addressCountWhenEditStarted);
        }
        else {
            _nonEditedAddresses = nil;
        }
            
        [resultingObjects addObject:address];
    }
    
    return resultingObjects;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
    SM_LOG_DEBUG(@"substring: '%@', tokenIndex: %ld", substring, tokenIndex);
    
    return [_suggestionProvider suggestionsForPrefix:substring];
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
	return [[SMAddress alloc] initWithStringRepresentation:editingString];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    NSAssert([representedObject isKindOfClass:[SMAddress class]], @"bad kind of object: %@", representedObject);
    
//    if([self editedAddress:representedObject]) {
//        SMAddress *addressElem = representedObject;
//        return [addressElem stringRepresentationDetailed];
//    }
//    else {
        SMAddress *addressElem = representedObject;
        return [addressElem stringRepresentationShort];
//    }
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject {
    NSAssert([representedObject isKindOfClass:[SMAddress class]], @"bad kind of object: %@", representedObject);
    
    if([self editedAddress:representedObject]) {
        SMAddress *addressElem = representedObject;
        return [addressElem stringRepresentationDetailed];
    }
    else {
        return nil;
    }
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LabeledTokenFieldEndedEditing" object:self userInfo:nil];
	return YES;
}

- (void)copyAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");
    
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:_addressWithMenu.stringRepresentationDetailed forType:NSStringPboardType];
}

- (void)editAddressAction:(NSMenuItem*)menuItem {
    SM_LOG_INFO(@"??");

    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");
    
    NSArray *objects = [NSArray arrayWithArray:_tokenField.objectValue];
    NSMutableArray *nonEditedAddresses = [NSMutableArray arrayWithArray:objects];
    [nonEditedAddresses removeObject:_addressWithMenu];
    
    _nonEditedAddresses = nonEditedAddresses;
    _addressCountWhenEditStarted = objects.lastObject == _addressWithMenu? objects.count : 0;
    SM_LOG_INFO(@"_addressCountWhenEditStarted->%lu",_addressCountWhenEditStarted);
    
    [_tokenField setStringValue:@""];
    [_tokenField setObjectValue:objects];
}

- (void)removeAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");
    
    NSTextView *textView = [[_tokenField cell] fieldEditorForView:_tokenField];
    [textView setSelectedRange:NSMakeRange(0, 0)];
  
    NSMutableArray *objects = [NSMutableArray arrayWithArray:_tokenField.objectValue];
    [objects removeObject:_addressWithMenu];
    
    [_tokenField setObjectValue:objects];
}

- (void)newMessageAction:(NSMenuItem*)menuItem {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] openMessageEditorWindow:nil subject:nil to:@[[_addressWithMenu mcoAddress]] cc:nil bcc:nil draftUid:0 mcoAttachments:nil];
}

- (void)openInAddressBookAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu, @"no address for menu");
    NSAssert(_addressWithMenuUniqueId, @"no address unique id for menu");

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] addressBookController] openAddressInAddressBook:_addressWithMenuUniqueId edit:NO];
}

- (void)addToAddressBookAction:(NSMenuItem*)menuItem {
    NSString *addressUniqueId = nil;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[[appDelegate model] addressBookController] addAddress:_addressWithMenu uniqueId:&addressUniqueId]) {
        [[[appDelegate model] addressBookController] openAddressInAddressBook:addressUniqueId edit:YES];
    }
    else {
        SM_LOG_ERROR(@"Could not add address '%@' to address book", _addressWithMenu.stringRepresentationDetailed);
    }
}

@end
