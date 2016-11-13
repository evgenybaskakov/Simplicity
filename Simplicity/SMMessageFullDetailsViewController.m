//
//  SMMessageFullDetailsViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMUserAccount.h"
#import "SMAddressBookController.h"
#import "SMTokenField.h"
#import "SMAddress.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageFullDetailsView.h"
#import "SMMessageFullDetailsViewController.h"
#import "SMHTMLMessageEditorView.h"
#import "SMMessageThreadCellViewController.h"

static const NSUInteger CONTACT_BUTTON_SIZE = 37;
static const NSUInteger MAX_ADDRESS_LIST_HEIGHT = 115;

@implementation SMMessageFullDetailsViewController {
    NSButton *_contactButton;
    NSTextField *_fromLabel;
    NSTokenField *_fromAddress;
    NSTextField *_toLabel;
    NSScrollView *_toScrollView;
    NSTokenField *_toAddresses;
    NSTextField *_ccLabel;
    NSTokenField *_ccAddresses;
    NSScrollView *_ccScrollView;
    NSLayoutConstraint *_toBottomConstraint;
    NSMutableArray *_ccConstraints;
    BOOL _ccCreated;
    BOOL _addressListsFramesValid;
    SMAddress *_addressWithMenu;
    NSString *_addressWithMenuUniqueId;
    NSLayoutConstraint *_toScrollViewHeightConstraint;
    NSLayoutConstraint *_ccScrollViewHeightConstraint;
    SMMessageThreadCellViewController __weak *_enclosingThreadCell;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _addressListsFramesValid = NO;
        
        SMMessageFullDetailsView *view = [[SMMessageFullDetailsView alloc] init];
        view.translatesAutoresizingMaskIntoConstraints = NO;

        [view setViewController:self];
        [self setView:view];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenFieldHeightChanged:) name:@"SMTokenFieldHeightChanged" object:nil];
        
        [self createSubviews];
    }
    
    return self;
}

- (void)dealloc {
    _fromAddress.delegate = nil;
    _toAddresses.delegate = nil;
    
    if(_ccAddresses) {
        _ccAddresses.delegate = nil;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setEnclosingThreadCell:(SMMessageThreadCellViewController *)enclosingThreadCell {
    _enclosingThreadCell = enclosingThreadCell;
}

#define V_GAP 10
#define V_GAP_HALF (V_GAP/2)

#define H_GAP 3

- (void)tokenFieldHeightChanged:(NSNotification*)notification {
    SMTokenField *tokenField = [[notification userInfo] objectForKey:@"Object"];
    NSNumber *height = [[notification userInfo] objectForKey:@"Height"];
    
    if(tokenField == _toAddresses) {
        _toScrollViewHeightConstraint.constant = MIN(MAX_ADDRESS_LIST_HEIGHT, height.floatValue);
    }
    else if(tokenField == _ccAddresses) {
        _ccScrollViewHeightConstraint.constant = MIN(MAX_ADDRESS_LIST_HEIGHT, height.floatValue);
    }
}

- (void)createSubviews {
    NSView *view = [self view];

    // init 'from' button
    _contactButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, CONTACT_BUTTON_SIZE, CONTACT_BUTTON_SIZE)];
    _contactButton.image = [NSImage imageNamed:NSImageNameUserGuest];
    _contactButton.title = @"";
    _contactButton.bezelStyle = NSTexturedSquareBezelStyle;
    _contactButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_contactButton.cell setImageScaling:NSImageScaleProportionallyUpOrDown];
    
    [view addSubview:_contactButton];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:CONTACT_BUTTON_SIZE]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:CONTACT_BUTTON_SIZE]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_contactButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_contactButton attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    
    // init 'from' label
    
    _fromLabel = [SMMessageDetailsViewController createLabel:@"From:" bold:NO];
    _fromLabel.textColor = [NSColor blackColor];
    
    [view addSubview:_fromLabel];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_fromLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    
    // init 'from' address
    
    _fromAddress = [[SMTokenField alloc] init];
    _fromAddress.delegate = self;
    _fromAddress.tokenStyle = NSPlainTextTokenStyle;
    _fromAddress.translatesAutoresizingMaskIntoConstraints = NO;
    [_fromAddress setBordered:NO];
    [_fromAddress setDrawsBackground:NO];
    [_fromAddress setEditable:NO];
    [_fromAddress setSelectable:YES];

    [view addSubview:_fromAddress];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_fromLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_fromLabel.frame.size.width]];

    // init 'to' label

    _toLabel = [SMMessageDetailsViewController createLabel:@"To:" bold:NO];
    _toLabel.textColor = [NSColor blackColor];
    
    [view addSubview:_toLabel];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];

    // init 'to' scroll view
    
    _toScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    _toScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _toScrollView.hasVerticalScroller = YES;
    _toScrollView.hasHorizontalScroller = NO;
    _toScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    _toScrollView.horizontalLineScroll = 0;
    _toScrollView.drawsBackground = YES;
    _toScrollView.borderType = NSNoBorder;

    // init 'to' address list
    
    _toAddresses = [[SMTokenField alloc] init];
    _toAddresses.delegate = self;
    _toAddresses.tokenStyle = NSPlainTextTokenStyle;
    _toAddresses.translatesAutoresizingMaskIntoConstraints = NO;
    [_toAddresses setBordered:NO];
    [_toAddresses setDrawsBackground:NO];
    [_toAddresses setEditable:NO];
    [_toAddresses setSelectable:YES];
    
    [_toAddresses setFrame:_toScrollView.frame];

    _toScrollView.documentView = _toAddresses;

    [_toAddresses.topAnchor constraintEqualToAnchor:_toScrollView.topAnchor constant:0].active = true;
    [_toAddresses.leftAnchor constraintEqualToAnchor:_toScrollView.leftAnchor constant:0].active = true;
    [_toAddresses.widthAnchor constraintEqualToAnchor:_toScrollView.widthAnchor constant:-6].active = true;

    _toScrollViewHeightConstraint = [_toScrollView.heightAnchor constraintEqualToConstant:MAX_ADDRESS_LIST_HEIGHT];
    _toScrollViewHeightConstraint.active = true;

    [view addSubview:_toScrollView];
    
    // setup constraints
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_toLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_toScrollView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toScrollView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_toScrollView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeRight multiplier:1.0 constant:-H_GAP]];
    
    _toBottomConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toScrollView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];

    [view addConstraint:_toBottomConstraint];
}

- (void)createCc {
    if(_ccCreated)
        return;
    
    NSView *view = [self view];

    if(_ccLabel == nil) {
        NSAssert(_ccAddresses == nil, @"cc addresses already created");
        NSAssert(_ccScrollView == nil, @"cc scroll view already created");
        NSAssert(_ccConstraints == nil, @"cc constraints already created");

        // init 'cc' label
        
        _ccLabel = [SMMessageDetailsViewController createLabel:@"Cc:" bold:NO];
        _ccLabel.textColor = [NSColor blackColor];
        
        _ccConstraints = [NSMutableArray array];

        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
        
        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_toScrollView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];

        // init 'cc' scroll view
        
        _ccScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        _ccScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _ccScrollView.hasVerticalScroller = YES;
        _ccScrollView.hasHorizontalScroller = NO;
        _ccScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        _ccScrollView.horizontalLineScroll = 0;
        _ccScrollView.drawsBackground = YES;
        _ccScrollView.borderType = NSNoBorder;
        
        // init 'cc' address list
        
        _ccAddresses = [[SMTokenField alloc] init];
        _ccAddresses.delegate = self;
        _ccAddresses.tokenStyle = NSPlainTextTokenStyle;
        _ccAddresses.translatesAutoresizingMaskIntoConstraints = NO;
        [_ccAddresses setBordered:NO];
        [_ccAddresses setDrawsBackground:NO];
        [_ccAddresses setEditable:NO];
        [_ccAddresses setSelectable:YES];
        
        [_ccAddresses setFrame:_ccScrollView.frame];
        
        _ccScrollView.documentView = _ccAddresses;
        
        [_ccAddresses.topAnchor constraintEqualToAnchor:_ccScrollView.topAnchor constant:0].active = true;
        [_ccAddresses.leftAnchor constraintEqualToAnchor:_ccScrollView.leftAnchor constant:0].active = true;
        [_ccAddresses.widthAnchor constraintEqualToAnchor:_ccScrollView.widthAnchor constant:-6].active = true;
        
        _ccScrollViewHeightConstraint = [_ccScrollView.heightAnchor constraintEqualToConstant:MAX_ADDRESS_LIST_HEIGHT];
        _ccScrollViewHeightConstraint.active = true;
        
        // setup constraints

        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_ccLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_ccScrollView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];

        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_toScrollView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccScrollView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
        
        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_ccScrollView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_ccLabel.frame.size.width]];

        [_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccScrollView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    }
    else {
        NSAssert(_ccAddresses != nil, @"cc addresses not created");
        NSAssert(_ccScrollView != nil, @"cc scroll view not created");
        NSAssert(_ccConstraints != nil, @"cc constraints not created");
    }
    
    NSAssert(_toBottomConstraint != nil, @"bottom constaint not created");
    [view removeConstraint:_toBottomConstraint];

    [view addSubview:_ccLabel];
    [view addSubview:_ccScrollView];
    [view addConstraints:_ccConstraints];
    
    _ccCreated = YES;
}

- (void)setMessage:(SMMessage*)message {
    [_fromAddress setObjectValue:message.fromAddress? @[message.fromAddress] : @[]];

    [_toAddresses setObjectValue:[SMAddress mcoAddressesToAddressList:message.toAddressList]];

    if(message.ccAddressList != nil && message.ccAddressList.count != 0) {
        [self createCc];

        [_ccAddresses setObjectValue:[SMAddress mcoAddressesToAddressList:message.ccAddressList]];
    }
    
    if(message.fromAddress) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        SMUserAccount *account = _enclosingThreadCell.messageThreadViewController.currentMessageThread.account;
        if([account.accountAddress matchEmail:message.fromAddress]) {
            _contactButton.image = account.accountImage;
        }
        else {
            SMMessageFullDetailsViewController __weak *weakSelf = self;
            BOOL allowWebSiteImage = [appDelegate.preferencesController shouldUseServerContactImages];
            NSImage *contactImage = [[appDelegate addressBookController] loadPictureForAddress:message.fromAddress searchNetwork:YES allowWebSiteImage:allowWebSiteImage tag:0 completionBlock:^(NSImage *image, NSInteger tag) {
                SMMessageFullDetailsViewController *_self = weakSelf;
                if(!_self) {
                    SM_LOG_WARNING(@"object is gone");
                    return;
                }
                if(image != nil) {
                    _self->_contactButton.image = image;
                }
            }];
            
            if(contactImage != nil) {
                _contactButton.image = contactImage;
            }
        }
    }
    
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

- (CGFloat)contentViewHeight {
    CGFloat topSpace = [_fromAddress intrinsicContentSize].height + V_GAP_HALF + MIN(MAX_ADDRESS_LIST_HEIGHT, [_toAddresses intrinsicContentSize].height);

    if(_ccAddresses != nil) {
        return topSpace + V_GAP_HALF + MIN(MAX_ADDRESS_LIST_HEIGHT, [_ccAddresses intrinsicContentSize].height);
    } else {
        return topSpace;
    }
}

- (void)invalidateIntrinsicContentViewSize {
    [[self view] setNeedsUpdateConstraints:YES];
}

#pragma mark - NSTokenFieldDelegate

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
    return YES;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    NSMenu *menu = [[NSMenu alloc] init];

    [menu addItemWithTitle:@"Copy address" action:@selector(copyAddressAction:) keyEquivalent:@""];
    
    NSString *addressUniqueId = nil;
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if([[appDelegate addressBookController] findAddress:representedObject uniqueId:&addressUniqueId]) {
        [menu addItemWithTitle:@"Open in address book" action:@selector(openInAddressBookAction:) keyEquivalent:@""];
    }
    else {
        [menu addItemWithTitle:@"Add to address book" action:@selector(addToAddressBookAction:) keyEquivalent:@""];
    }
    
    [menu addItemWithTitle:@"New message" action:@selector(newMessageAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Reply" action:@selector(replyAction:) keyEquivalent:@""];
    
    _addressWithMenu = representedObject;
    _addressWithMenuUniqueId = addressUniqueId;
    
    return menu;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    NSAssert([representedObject isKindOfClass:[SMAddress class]], @"bad kind of object: %@", representedObject);
    
    SMAddress *addressElem = representedObject;
    return addressElem.detailedRepresentation;
}

- (void)copyAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");

    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:_addressWithMenu.detailedRepresentation forType:NSStringPboardType];
}

- (void)replyAction:(NSMenuItem*)menuItem {
    [SMNotificationsController localNotifyComposeMessageReply:_enclosingThreadCell replyKind:SMEditorReplyKind_Forward toAddress:_addressWithMenu];
}

- (void)newMessageAction:(NSMenuItem*)menuItem {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    BOOL plainText = [appDelegate.preferencesController preferableMessageFormat] == SMPreferableMessageFormat_RawText? YES : NO;
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
