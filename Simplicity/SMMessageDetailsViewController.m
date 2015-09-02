//
//  SMMessageDetailsViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/11/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMImageRegistry.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageFullDetailsViewController.h"
#import "SMMessageThreadCellViewController.h"
#import "SMMessage.h"

static const CGFloat HEADER_ICON_HEIGHT_RATIO = 1.8;

@implementation SMMessageDetailsViewController {
	// current message control objects
	SMMessage *_currentMessage;
	SMMessageFullDetailsViewController *_fullDetailsViewController;

	// the thread cell that contains this message details view
	// must be weak to avoid mutual dependency cycle
	SMMessageThreadCellViewController __weak *_enclosingThreadCell;
	
	// UI elements
	NSButton *_starButton;
	NSTextField *_fromAddress;
	NSTextField *_toList;
	NSButton *_attachmentButton;
	NSTextField *_date;
	NSButton *_infoButton;
    NSButton *_replyButton;
    NSButton *_messageActionsButton;
	Boolean _fullDetailsShown;
	NSMutableArray *_fullDetailsViewConstraints;
	NSLayoutConstraint *_bottomConstraint;
	Boolean _fullHeaderShown;
	NSMutableArray *_uncollapsedHeaderConstraints;
	NSLayoutConstraint *_collapsedHeaderConstraint;
	NSMutableArray *_hasAttachmentsConstraints;
	NSMutableArray *_doesntHaveAttachmentsConstraints;
	Boolean _attachmentButtonShown;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		NSView *view = [[NSView alloc] init];
		view.translatesAutoresizingMaskIntoConstraints = NO;
		[self setView:view];
		[self createSubviews];
	}
	
	return self;
}

+ (NSUInteger)headerHeight {
	return 36;
}

+ (CGFloat)headerIconHeightRatio {
	return HEADER_ICON_HEIGHT_RATIO;
}

+ (NSTextField*)createLabel:(NSString*)text bold:(BOOL)bold {
	NSTextField *label = [[NSTextField alloc] init];
	
	[label setStringValue:text];
	[label setBordered:YES];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setFrameSize:[label fittingSize]];
	[label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	const NSUInteger fontSize = 12;
	[label setFont:(bold? [NSFont boldSystemFontOfSize:fontSize] : [NSFont systemFontOfSize:fontSize])];

	return label;
}

- (void)setEnclosingThreadCell:(SMMessageThreadCellViewController *)enclosingThreadCell {
	_enclosingThreadCell = enclosingThreadCell;
}

- (void)setMessage:(SMMessage*)message {
	NSAssert(message != nil, @"nil message");
	
	if(_currentMessage != message) {
		_currentMessage = message;
		
		[_fromAddress setStringValue:[_currentMessage from]];
		[_date setStringValue:[_currentMessage localizedDate]];
	}

	[self updateMessage];
}

- (void)updateMessage {
	NSAssert(_currentMessage != nil, @"nil message");
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	if(_currentMessage.flagged) {
		_starButton.image = appDelegate.imageRegistry.yellowStarImage;
	} else {
		_starButton.image = appDelegate.imageRegistry.grayStarImage;
	}

	if(_currentMessage.hasAttachments) {
		[self showAttachmentButton];
	} else {
		[self hideAttachmentButton];
	}

	NSString *toListString = @"to";
	NSUInteger toCount = 0;
	
	for(MCOAddress *a in [_currentMessage.header to]) {
		toListString = [NSString stringWithFormat:(toCount? @"%@, %@" : @"%@ %@"), toListString, [SMMessage parseAddress:a]];
		toCount++;
	}
	
	for(MCOAddress *a in [_currentMessage.header cc]) {
		toListString = [NSString stringWithFormat:(toCount? @"%@, %@" : @"%@ %@"), toListString, [SMMessage parseAddress:a]];
		toCount++;
	}
	
	[_toList setStringValue:(toCount > 0? toListString : @"")];

	NSFont *font = [_toList font];
	
	font = _currentMessage.unseen? [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait] : [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSFontBoldTrait];
	
	[_toList setFont:font];
	
	[_fullDetailsViewController setMessage:_currentMessage];
}

#define V_MARGIN 10
#define H_MARGIN 6
#define FROM_W 5
#define H_GAP 5
#define V_GAP 10
#define V_GAP_HALF (V_GAP/2)

- (void)createSubviews {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	NSView *view = [self view];

	// init star button

	_starButton = [[NSButton alloc] init];
	_starButton.translatesAutoresizingMaskIntoConstraints = NO;
	_starButton.bezelStyle = NSShadowlessSquareBezelStyle;
	_starButton.target = self;
	_starButton.image = appDelegate.imageRegistry.grayStarImage;
	[_starButton.cell setImageScaling:NSImageScaleProportionallyDown];
	_starButton.bordered = NO;
	_starButton.action = @selector(changeMessageFlaggedFlag:);

	[view addSubview:_starButton];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController headerHeight]/HEADER_ICON_HEIGHT_RATIO]];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];
	
	// init from address label
	
	_fromAddress = [SMMessageDetailsViewController createLabel:@"" bold:YES];
	_fromAddress.textColor = [NSColor blueColor];

	[_fromAddress.cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[_fromAddress setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationHorizontal];

	[view addSubview:_fromAddress];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

	// init date label
	
	_date = [SMMessageDetailsViewController createLabel:@"" bold:NO];
	_date.textColor = [NSColor grayColor];
	
	[view addSubview:_date];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_date attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];
	
	// init header collapsing

	_collapsedHeaderConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_date attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP];
	
	[view addConstraint:_collapsedHeaderConstraint];

	// init subject
	
	_toList = [SMMessageDetailsViewController createLabel:@"" bold:NO];
	_toList.textColor = [NSColor blackColor];

	[_toList.cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[_toList setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-2 forOrientation:NSLayoutConstraintOrientationHorizontal];
	
	[view addSubview:_toList];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_toList attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-FROM_W]];

	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_toList attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

	// init attachment constraints
	
	_doesntHaveAttachmentsConstraints = [NSMutableArray array];

	[_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
	
	[_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_toList attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_date attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
	
	[_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
	
	[view addConstraints:_doesntHaveAttachmentsConstraints];

	// init bottom constraint

	_bottomConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toList attribute:NSLayoutAttributeBottom multiplier:1.0 constant:V_MARGIN];
	
	[view addConstraint:_bottomConstraint];
}

- (void)showAttachmentButton {
	if(_attachmentButtonShown)
		return;
	
	NSView *view = [self view];

	if(_attachmentButton == nil) {
		NSAssert(_hasAttachmentsConstraints == nil, @"_hasAttachmentsConstraints != nil");

		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

		_attachmentButton = [[NSButton alloc] init];
		_attachmentButton.translatesAutoresizingMaskIntoConstraints = NO;
		_attachmentButton.bezelStyle = NSShadowlessSquareBezelStyle;
		_attachmentButton.image = appDelegate.imageRegistry.attachmentImage;
		[_attachmentButton.cell setImageScaling:NSImageScaleProportionallyDown];
		_attachmentButton.bordered = NO;
		//_attachmentButton.target = self;
		//_attachmentButton.action = @selector(toggleAttachmentsPanel:);
		
		// TODO: show popup menu asking the user to save/download the attachments
		//	_attachmentButton.action = @selector(toggleFullDetails:);
		
		_hasAttachmentsConstraints = [NSMutableArray array];
		
		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_attachmentButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController headerHeight]/HEADER_ICON_HEIGHT_RATIO]];
		
		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_attachmentButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
		
		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_attachmentButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:H_GAP]];
		
		[_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
		
		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_date attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];

		[_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];

		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_toList attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_attachmentButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];

		[_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];

		[_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
		
		[_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];
	}

	NSAssert(_doesntHaveAttachmentsConstraints != nil, @"_doesntHaveAttachmentsConstraints == nil");
	[view removeConstraints:_doesntHaveAttachmentsConstraints];
	
	NSAssert(_attachmentButton != nil, @"_attachmentButton == nil");
	[view addSubview:_attachmentButton];

	NSAssert(_hasAttachmentsConstraints != nil, @"_hasAttachmentsConstraints == nil");
	[view addConstraints:_hasAttachmentsConstraints];

	_attachmentButtonShown = YES;
}

- (void)hideAttachmentButton {
	if(!_attachmentButtonShown)
		return;
	
	NSView *view = [self view];
	
	NSAssert(_hasAttachmentsConstraints != nil, @"_hasAttachmentsConstraints == nil");
	[view removeConstraints:_hasAttachmentsConstraints];
	
	NSAssert(_attachmentButton != nil, @"_attachmentButton == nil");
	[_attachmentButton removeFromSuperview];
	
	[view addConstraints:_doesntHaveAttachmentsConstraints];
	
	_attachmentButtonShown = NO;
}

- (void)showFullDetails {
	if(_fullDetailsShown)
		return;

	if(_fullDetailsViewController == nil)
		_fullDetailsViewController = [[SMMessageFullDetailsViewController alloc] init];
	
	if(_currentMessage != nil)
		[_fullDetailsViewController setMessage:_currentMessage];

	NSView *view = [self view];
	NSAssert(view != nil, @"no view");

	NSView *subview = [_fullDetailsViewController view];
	NSAssert(subview != nil, @"no full details view");
	
	[view addSubview:subview];

	NSAssert(_bottomConstraint != nil, @"no bottom constraint");
	[view removeConstraint:_bottomConstraint];
	
	if(_fullDetailsViewConstraints == nil) {
		_fullDetailsViewConstraints = [NSMutableArray array];
		
		[_fullDetailsViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:subview attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];
		
		[_fullDetailsViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:subview attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN]];
		
		[_fullDetailsViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_toList attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:subview attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP]];
		
		[_fullDetailsViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:subview attribute:NSLayoutAttributeBottom multiplier:1.0 constant:V_MARGIN]];
	}

	[view addConstraints:_fullDetailsViewConstraints];
	
	_fullDetailsShown = YES;
}

- (void)hideFullDetails {
	if(!_fullDetailsShown)
		return;

	NSView *view = [self view];
	NSAssert(view != nil, @"no view");

	NSAssert(_fullDetailsViewConstraints != nil, @"no full details view constraint");
	[view removeConstraints:_fullDetailsViewConstraints];

	NSAssert(_fullDetailsViewController != nil, @"no full details view controller");
	[[_fullDetailsViewController view] removeFromSuperview];
	
	[view addConstraint:_bottomConstraint];
	
	_fullDetailsShown = NO;
}

- (void)uncollapse {
	if(_fullHeaderShown)
		return;

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	NSView *view = [self view];
	NSAssert(view != nil, @"no view");

	if(_infoButton == nil) {
        NSAssert(_replyButton == nil, @"reply button already created");
        NSAssert(_messageActionsButton == nil, @"message actions button already created");

		_infoButton = [[NSButton alloc] init];
		_infoButton.translatesAutoresizingMaskIntoConstraints = NO;
		_infoButton.bezelStyle = NSShadowlessSquareBezelStyle;
		_infoButton.target = self;
		_infoButton.image = appDelegate.imageRegistry.infoImage;
		[_infoButton.cell setImageScaling:NSImageScaleProportionallyDown];
		_infoButton.bordered = NO;
		_infoButton.action = @selector(toggleFullDetails:);

        _replyButton = [[NSButton alloc] init];
        _replyButton.translatesAutoresizingMaskIntoConstraints = NO;
        _replyButton.bezelStyle = NSShadowlessSquareBezelStyle;
        _replyButton.target = self;
        _replyButton.image = appDelegate.imageRegistry.replyImage; // TODO: optionally show replyAll
        [_replyButton.cell setImageScaling:NSImageScaleProportionallyDown];
        _replyButton.bordered = NO;
        _replyButton.action = @selector(composeReply:);

        _messageActionsButton = [[NSButton alloc] init];
        _messageActionsButton.translatesAutoresizingMaskIntoConstraints = NO;
        _messageActionsButton.bezelStyle = NSShadowlessSquareBezelStyle;
        _messageActionsButton.target = self;
        _messageActionsButton.image = appDelegate.imageRegistry.moreMessageActionsImage;
        [_messageActionsButton.cell setImageScaling:NSImageScaleProportionallyDown];
        _messageActionsButton.bordered = NO;
        _messageActionsButton.action = @selector(showMessageActions:);
        
		NSAssert(_uncollapsedHeaderConstraints == nil, @"_uncollapsedHeaderConstraints already created");
		_uncollapsedHeaderConstraints = [NSMutableArray array];

        for(NSButton *button in [NSArray arrayWithObjects:_infoButton, _replyButton, _messageActionsButton, nil]) {
            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController headerHeight]/HEADER_ICON_HEIGHT_RATIO]];

            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:button attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
            
            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:button attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
            [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired];
        }
        
		[_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_infoButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_date attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
		[_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_replyButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_infoButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageActionsButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_replyButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_messageActionsButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];
	}

	NSAssert(_collapsedHeaderConstraint != nil, @"_collapsedHeaderConstraint is nil");
	[view removeConstraint:_collapsedHeaderConstraint];

	[view addSubview:_infoButton];
    [view addSubview:_replyButton];
    [view addSubview:_messageActionsButton];
	[view addConstraints:_uncollapsedHeaderConstraints];

	_fullHeaderShown = YES;
}

- (void)collapse {
	if(!_fullHeaderShown)
		return;
	
	[self hideFullDetails];
	
	NSView *view = [self view];
	NSAssert(view != nil, @"no view");
	
	[view removeConstraints:_uncollapsedHeaderConstraints];
	[_infoButton removeFromSuperview];
    [_replyButton removeFromSuperview];
    [_messageActionsButton removeFromSuperview];

	[view addConstraint:_collapsedHeaderConstraint];
	
	_fullHeaderShown = NO;
}

#pragma mark Actions

- (void)toggleFullDetails:(id)sender {
	if(_fullDetailsShown) {
		[self hideFullDetails];
	} else {
		[self showFullDetails];
	}

	// this must be done to keep the proper details panel height
	[[self view] invalidateIntrinsicContentSize];

    // notify external observers that they should adjust their contents
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageThreadCellHeightChanged" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", nil]];
}

- (void)composeReply:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", @"Reply", @"ReplyKind", nil]];
}

- (void)composeReplyAll:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", @"ReplyAll", @"ReplyKind", nil]];
}

- (void)composeForward:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", @"Forward", @"ReplyKind", nil]];
}

- (void)deleteMessage:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteMessage" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", nil]];
}

- (void)changeMessageUnreadFlag:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChangeMessageUnreadFlag" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", nil]];
}

- (void)changeMessageFlaggedFlag:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChangeMessageFlaggedFlag" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", nil]];
}

- (void)showMessageActions:(id)sender {
    NSMenu *theMenu = [[NSMenu alloc] init];

    [theMenu setAutoenablesItems:NO];

    [[theMenu addItemWithTitle:@"Reply" action:@selector(composeReply:) keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:@"Reply All" action:@selector(composeReplyAll:) keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:@"Forward" action:@selector(composeForward:) keyEquivalent:@""] setTarget:self];
    [theMenu addItem:[NSMenuItem separatorItem]];
    [[theMenu addItemWithTitle:@"Delete" action:@selector(deleteMessage:) keyEquivalent:@""] setTarget:self];
    [theMenu addItem:[NSMenuItem separatorItem]];
    [[theMenu addItemWithTitle:(_currentMessage.unseen? @"Mark as Read" : @"Mark as Unread") action:@selector(changeMessageUnreadFlag:) keyEquivalent:@""] setTarget:self];
    
    NSPoint menuPosition = NSMakePoint(_messageActionsButton.bounds.origin.x, _messageActionsButton.bounds.origin.y + _messageActionsButton.bounds.size.height);
    
    [theMenu popUpMenuPositioningItem:nil atLocation:menuPosition inView:_messageActionsButton];
}

#pragma mark Intrinsic size

- (NSSize)intrinsicContentViewSize {
	if(_fullDetailsShown) {
		return NSMakeSize(-1, V_MARGIN + _fromAddress.frame.size.height + V_GAP + _fullDetailsViewController.view.intrinsicContentSize.height + V_MARGIN);
	} else {
		return NSMakeSize(-1, V_MARGIN + _fromAddress.frame.size.height + V_MARGIN);
	}
}

- (void)invalidateIntrinsicContentViewSize {
	[[self view] setNeedsUpdateConstraints:YES];
}

@end
