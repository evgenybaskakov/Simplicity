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
#import "SMPreferencesController.h"
#import "SMAddressBookController.h"
#import "SMSuggestionProvider.h"
#import "SMTokenField.h"
#import "SMLabeledTokenFieldBoxView.h"
#import "SMAddress.h"
#import "SMAddressFieldViewController.h"

static const NSUInteger MAX_ADDRESS_LIST_HEIGHT = 83;

static NSPasteboard *_lastPasteboardUsed;
static SMAddressFieldViewController *_lastAddressFieldUsed;
static NSArray *_lastAddressesUsed;

@implementation SMAddressFieldViewController {
    Boolean _tokenFieldFrameValid;
    SMAddress *_addressWithMenu;
    NSArray *_nonEditedAddresses;
    NSString *_addressWithMenuUniqueId;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSView *view = [self view];

    NSAssert([view isKindOfClass:[SMLabeledTokenFieldBoxView class]], @"view not SMLabeledTokenFieldBoxView");
    
    [(SMLabeledTokenFieldBoxView*)view setViewController:self];

    _tokenField = [[SMTokenField alloc] init];
    _tokenField.delegate = self; // TODO: reference loop here?
    _tokenField.tokenStyle = NSPlainTextTokenStyle;
    _tokenField.translatesAutoresizingMaskIntoConstraints = NO;
    _tokenField.bordered = NO;
    _tokenField.drawsBackground = NO;
    _tokenField.editable = YES;
    _tokenField.selectable = YES;
    _tokenField.cell.sendsActionOnEndEditing = YES;

    [_tokenField setFrame:_scrollView.frame];
    
    _scrollView.documentView = _tokenField;
    
    [_tokenField.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:0].active = true;
    [_tokenField.leftAnchor constraintEqualToAnchor:_scrollView.leftAnchor constant:0].active = true;
    [_tokenField.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-6].active = true;

    [_scrollView.heightAnchor constraintLessThanOrEqualToConstant:MAX_ADDRESS_LIST_HEIGHT].active = true;
}

- (void)dealloc {
    _tokenField.delegate = nil;
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

- (CGFloat)contentViewHeight {
    return MIN(MAX_ADDRESS_LIST_HEIGHT, _tokenField.intrinsicContentSize.height) + _topTokenFieldContraint.constant + _bottomTokenFieldContraint.constant;
}

- (void)invalidateIntrinsicContentViewSize {
    [[self view] setNeedsUpdateConstraints:YES];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == _tokenField) {
        SM_LOG_DEBUG(@"obj.object: %@", obj);

        NSArray *objects = _tokenField.objectValue;
        
        if(objects.count == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AddressFieldContentsChanged" object:self userInfo:nil];
        }
    }
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
    _controlSwitch.refusesFirstResponder = YES;

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
    SM_LOG_DEBUG(@"representeObject: %@", representedObject);

    NSMenu *menu = [[NSMenu alloc] init];
    
    [menu addItemWithTitle:@"Copy address" action:@selector(copyAddressAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Edit address" action:@selector(editAddressAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Remove address" action:@selector(removeAddressAction:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];

    NSString *addressUniqueId = nil;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([[appDelegate addressBookController] findAddress:representedObject uniqueId:&addressUniqueId]) {
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
    NSMutableArray *resultingObjects = [NSMutableArray array];
    
    for(id token in tokens) {
        SMAddress *address = nil;
        
        if([token isKindOfClass:[SMAddress class]]) {
            address = token;
        }
        else {
            address = [[SMAddress alloc] initWithStringRepresentation:token];
        }
        
        [resultingObjects addObject:address];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddressFieldContentsChanged" object:self userInfo:nil];

    return resultingObjects;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
    SM_LOG_DEBUG(@"substring: '%@', tokenIndex: %ld", substring, tokenIndex);
    
    *selectedIndex = 0;
    
    NSArray *suggestions = [_suggestionProvider suggestionsForPrefix:substring];
    return suggestions.count > 1? suggestions : nil;
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
    return [[SMAddress alloc] initWithStringRepresentation:editingString];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    NSAssert([representedObject isKindOfClass:[SMAddress class]], @"bad kind of object: %@", representedObject);
    
//    if([self editedAddress:representedObject]) {
//        SMAddress *addressElem = representedObject;
//        return addressElem.detailedRepresentation;
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
        return addressElem.detailedRepresentation;
    }
    else {
        return nil;
    }
}

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *stringObjects = [NSMutableArray array];
    for(id address in objects) {
        NSAssert([address isKindOfClass:[SMAddress class]], @"bad address type");
        [stringObjects addObject:((SMAddress*)address).detailedRepresentation];
    }
    [pboard writeObjects:stringObjects];

    if(pboard != [NSPasteboard generalPasteboard]) {
        _lastPasteboardUsed = pboard;
        _lastAddressFieldUsed = self;
        _lastAddressesUsed = objects;
    }
    else {
        _lastPasteboardUsed = nil;
        _lastAddressFieldUsed = nil;
        _lastAddressesUsed = nil;
    }
    
    return YES;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard {
    NSArray *stringObjects = [pboard readObjectsForClasses:@[[NSString class]] options:nil];
    NSMutableArray *objects = [NSMutableArray array];
    for(NSString *address in stringObjects) {
        [objects addObject:[[SMAddress alloc] initWithStringRepresentation:address]];
    }
    
    if(pboard == _lastPasteboardUsed && _lastAddressFieldUsed != nil && _lastAddressFieldUsed != self && _lastAddressesUsed != nil) {
        [_lastAddressFieldUsed removeAddresses:_lastAddressesUsed];
    }
    
    _lastPasteboardUsed = nil;
    _lastAddressFieldUsed = nil;
    _lastAddressesUsed = nil;
    
    return objects;
}

- (void)removeAddresses:(NSArray*)addresses {
    NSMutableArray *objects = [NSMutableArray arrayWithArray:_tokenField.objectValue];
    [objects removeObjectsInArray:addresses];
    [_tokenField setObjectValue:objects];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddressFieldContentsChanged" object:self userInfo:nil];
    return YES;
}

#pragma mark Menu actions

- (void)copyAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");
    
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:_addressWithMenu.detailedRepresentation forType:NSStringPboardType];
}

- (void)editAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");
    
    // First, remember which addresses we are not going to change.
    // This will be used later when proper token style is chosen.
    NSArray *objects = [NSArray arrayWithArray:_tokenField.objectValue];
    NSMutableArray *nonEditedAddresses = [NSMutableArray arrayWithArray:objects];
    [nonEditedAddresses removeObject:_addressWithMenu];
    
    _nonEditedAddresses = nonEditedAddresses;

    // Next, trigger the token field content update.
    // There's no explicit "reloadData" method, so the only way to force it to redraw the
    // edited address as plain text is to reset the token field object value.
    [_tokenField setStringValue:@""];
    [_tokenField setObjectValue:objects];

    // Additional step: set the cursor position at the beginning of the
    // edited address token.
    NSUInteger addressIndex = [objects indexOfObject:_addressWithMenu];
    [[_tokenField.cell fieldEditorForView:_tokenField] setSelectedRange:NSMakeRange(addressIndex, 0)];
    
    // There is no straight way to tell the token field: "draw this token as plain text only
    // when it's being edited". Also, we can't mark the address object itself as such, because
    // they're going to be re-added a random number of times before any user action is taken.
    // In other words, there's no way to tell whether 'shouldAddObjects' is called because
    // of a user action or because of some internal token field business logic. So, here's the
    // solution: shedule a delayed edited address invalidation. After the event is fired,
    // any user action will trigger the edited address redrawing as 'blue pill', thus
    // finishing the editing mode.
    [self performSelector:@selector(disableAddressEditing) withObject:nil afterDelay:0.8];
}

- (void)disableAddressEditing {
    _nonEditedAddresses = nil;
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
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    Boolean plainText = [appDelegate.preferencesController preferableMessageFormat] == SMPreferableMessageFormat_RawText? YES : NO;
    [[appDelegate appController] openMessageEditorWindow:nil plainText:plainText subject:nil to:@[_addressWithMenu] cc:nil bcc:nil draftUid:0 mcoAttachments:nil editorKind:kEmptyEditorContentsKind];
}

- (void)openInAddressBookAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu, @"no address for menu");
    NSAssert(_addressWithMenuUniqueId, @"no address unique id for menu");

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate addressBookController] openAddressInAddressBook:_addressWithMenuUniqueId edit:NO];
}

- (void)addToAddressBookAction:(NSMenuItem*)menuItem {
    NSString *addressUniqueId = nil;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([[appDelegate addressBookController] addAddress:_addressWithMenu uniqueId:&addressUniqueId]) {
        [[appDelegate addressBookController] openAddressInAddressBook:addressUniqueId edit:YES];
    }
    else {
        SM_LOG_ERROR(@"Could not add address '%@' to address book", _addressWithMenu.detailedRepresentation);
    }
}

@end
