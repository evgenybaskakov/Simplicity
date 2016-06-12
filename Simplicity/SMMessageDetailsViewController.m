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
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMImageRegistry.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageFullDetailsViewController.h"
#import "SMMessageThreadCellViewController.h"
#import "SMAddressBookController.h"
#import "SMRoundedImageView.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMPreferencesController.h"

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
    SMRoundedImageView *_contactImageView;
    NSTextField *_fromAddress;
    NSTextField *_messageBodyPreviewField;
    NSTextField *_draftLabel;
    NSButton *_attachmentButton;
    NSTextField *_dateLabel;
    NSButton *_infoButton;
    NSButton *_replyOrEditButton;
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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setReplyButtonImage) name:@"DefaultReplyActionChanged" object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSUInteger)messageDetaisHeaderHeight {
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
        
        [_fromAddress setStringValue:[SMMessage parseAddress:_currentMessage.fromAddress]];
        [_dateLabel setStringValue:[_currentMessage localizedDate]];
        
        if([_currentMessage isKindOfClass:[SMOutgoingMessage class]]) {
            _starButton.enabled = NO;
        }
        
        if(_currentMessage && _currentMessage.draft) {
            _replyOrEditButton.action = @selector(editDraft:);
        }
        else {
            _replyOrEditButton.action = @selector(composeReplyOrReplyAll:);
        }

        [self setReplyButtonImage];
    }

    [self updateMessage];
}

- (void)updateMessage {
    NSAssert(_currentMessage != nil, @"nil message");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    NSImage *contactImage = [[appDelegate addressBookController] pictureForEmail:[_currentMessage.fromAddress mailbox]];
    if(contactImage != nil) {
        _contactImageView.image = contactImage;
    }

    if(_currentMessage.flagged) {
        _starButton.image = appDelegate.imageRegistry.yellowStarImage;
    } else {
        _starButton.image = appDelegate.imageRegistry.grayStarImage;
    }

    if(_doesntHaveAttachmentsConstraints != nil) {
        [self.view removeConstraints:_doesntHaveAttachmentsConstraints];
        _doesntHaveAttachmentsConstraints = nil;
    }
    
    if(_hasAttachmentsConstraints != nil) {
        [self.view removeConstraints:_hasAttachmentsConstraints];
        _hasAttachmentsConstraints = nil;
    }
    
    if(_currentMessage.hasAttachments) {
        [self showAttachmentButton];
    } else {
        [self hideAttachmentButton];
    }
    
    NSString *plainTextMessageBody = [_currentMessage plainTextBody];
    if(plainTextMessageBody == nil) {
        plainTextMessageBody = @"";
    }
    [_messageBodyPreviewField setStringValue:plainTextMessageBody];

    NSFont *font = [_messageBodyPreviewField font];
    
    font = _currentMessage.unseen? [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait] : [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSFontBoldTrait];
    
    [_messageBodyPreviewField setFont:font];
    
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

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/HEADER_ICON_HEIGHT_RATIO]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];
    
    // init contact image view
    
    _contactImageView = [[SMRoundedImageView alloc] init];
    _contactImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _contactImageView.image = [NSImage imageNamed:NSImageNameUserGuest];
    _contactImageView.cornerRadius = 1;
    _contactImageView.borderWidth = 1;
    _contactImageView.borderColor = [NSColor lightGrayColor];
    _contactImageView.nonOriginalBehavior = YES;
    _contactImageView.scaleImage = YES;
    
    [view addSubview:_contactImageView];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactImageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/HEADER_ICON_HEIGHT_RATIO]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactImageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_contactImageView attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_contactImageView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactImageView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

    // init from address label
    
    _fromAddress = [SMMessageDetailsViewController createLabel:@"" bold:YES];
    _fromAddress.textColor = [NSColor blueColor];

    [_fromAddress.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    [_fromAddress setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    [view addSubview:_fromAddress];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_contactImageView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

    // init date label
    
    _dateLabel = [SMMessageDetailsViewController createLabel:@"" bold:NO];
    _dateLabel.textColor = [NSColor grayColor];
    
    [view addSubview:_dateLabel];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_dateLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];
    
    // init header collapsing

    _collapsedHeaderConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_dateLabel attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP];
    
    [view addConstraint:_collapsedHeaderConstraint];

    // init subject
    
    _messageBodyPreviewField = [SMMessageDetailsViewController createLabel:@"" bold:NO];
    _messageBodyPreviewField.textColor = [NSColor blackColor];

    [_messageBodyPreviewField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    [_messageBodyPreviewField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-2 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [view addSubview:_messageBodyPreviewField];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_messageBodyPreviewField attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-FROM_W]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_messageBodyPreviewField attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

    // init bottom constraint

    _bottomConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_messageBodyPreviewField attribute:NSLayoutAttributeBottom multiplier:1.0 constant:V_MARGIN];
    
    [view addConstraint:_bottomConstraint];
}

- (void)setReplyButtonImage {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    if(_currentMessage && _currentMessage.draft) {
        _replyOrEditButton.image = appDelegate.imageRegistry.editImage;
    }
    else {
        _replyOrEditButton.image = [[appDelegate preferencesController] defaultReplyAction] == SMDefaultReplyAction_ReplyAll? appDelegate.imageRegistry.replyAllImage : appDelegate.imageRegistry.replyImage;
    }
}

- (NSTextField*)createDraftLabel {
    NSTextField *label = [SMMessageDetailsViewController createLabel:@"Draft" bold:NO];
    label.backgroundColor = [NSColor colorWithCalibratedRed:1 green:0.804262 blue:0.400805 alpha:1];
    label.drawsBackground = YES;

    [label setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    return label;
}

- (void)showAttachmentButton {
    NSView *view = [self view];

    if(_currentMessage && _currentMessage.draft) {
        if(_draftLabel == nil) {
            _draftLabel = [self createDraftLabel];
        }
        
        [view addSubview:_draftLabel];
    }
    else if(_draftLabel != nil) {
        [_draftLabel removeFromSuperview];
    }

    if(_attachmentButton == nil) {
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
        //  _attachmentButton.action = @selector(toggleFullDetails:);
    }
    
    NSAssert(_hasAttachmentsConstraints == nil, @"_hasAttachmentsConstraints != nil");
    _hasAttachmentsConstraints = [NSMutableArray array];
    
    [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_attachmentButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/HEADER_ICON_HEIGHT_RATIO]];
    
    [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_attachmentButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_attachmentButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:H_GAP]];
    
    [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
    
    [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_dateLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];

    [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];

    if(_currentMessage.draft) {
        [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_draftLabel attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
        
        [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];
        
        [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_draftLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];

        [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];

        [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyPreviewField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_draftLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        
        [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
    }
    else {
        [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyPreviewField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_attachmentButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];

        [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
    }

    [_hasAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_attachmentButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    
    [_hasAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];
    
    NSAssert(_attachmentButton != nil, @"_attachmentButton == nil");
    [view addSubview:_attachmentButton];

    NSAssert(_hasAttachmentsConstraints != nil, @"_hasAttachmentsConstraints == nil");
    [view addConstraints:_hasAttachmentsConstraints];
}

- (void)hideAttachmentButton {
    NSView *view = [self view];
    
    if(_attachmentButton != nil) {
        [_attachmentButton removeFromSuperview];
    }
    
    if(_currentMessage && _currentMessage.draft) {
        if(_draftLabel == nil) {
            _draftLabel = [self createDraftLabel];
        }
        
        [view addSubview:_draftLabel];
    }
    else if(_draftLabel != nil) {
        [_draftLabel removeFromSuperview];
    }
    
    NSAssert(_doesntHaveAttachmentsConstraints == nil, @"_doesntHaveAttachmentsConstraints != nil");
    _doesntHaveAttachmentsConstraints = [NSMutableArray array];

    if(_currentMessage && _currentMessage.draft) {
        [_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_draftLabel attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
        
        [_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];

        [_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_draftLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_dateLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        
        [_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];

        [_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyPreviewField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_draftLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        
        [_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];

        [_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_draftLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];
        
        [_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityRequired];
    }
    else {
        [_doesntHaveAttachmentsConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyPreviewField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_dateLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        
        [_doesntHaveAttachmentsConstraints.lastObject setPriority:NSLayoutPriorityDefaultLow];
    }
    
    [view addConstraints:_doesntHaveAttachmentsConstraints];
}

- (void)showFullDetails {
    if(_fullDetailsShown)
        return;

    if(_fullDetailsViewController == nil) {
        _fullDetailsViewController = [[SMMessageFullDetailsViewController alloc] init];
        [_fullDetailsViewController setEnclosingThreadCell:_enclosingThreadCell];
    }
    
    if(_currentMessage != nil) {
        [_fullDetailsViewController setMessage:_currentMessage];
    }

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
        
        [_fullDetailsViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyPreviewField attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:subview attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP]];
        
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
        NSAssert(_replyOrEditButton == nil, @"reply button already created");
        NSAssert(_messageActionsButton == nil, @"message actions button already created");

        _infoButton = [[NSButton alloc] init];
        _infoButton.translatesAutoresizingMaskIntoConstraints = NO;
        _infoButton.bezelStyle = NSShadowlessSquareBezelStyle;
        _infoButton.target = self;
        _infoButton.image = appDelegate.imageRegistry.infoImage;
        [_infoButton.cell setImageScaling:NSImageScaleProportionallyDown];
        _infoButton.bordered = NO;
        _infoButton.action = @selector(toggleFullDetails:);

        _replyOrEditButton = [[NSButton alloc] init];
        _replyOrEditButton.translatesAutoresizingMaskIntoConstraints = NO;
        _replyOrEditButton.bezelStyle = NSShadowlessSquareBezelStyle;
        _replyOrEditButton.target = self;
        [_replyOrEditButton.cell setImageScaling:NSImageScaleProportionallyDown];
        _replyOrEditButton.bordered = NO;
        _replyOrEditButton.action = @selector(composeReplyOrReplyAll:);
        [self setReplyButtonImage];

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

        for(NSButton *button in [NSArray arrayWithObjects:_infoButton, _replyOrEditButton, _messageActionsButton, nil]) {
            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/HEADER_ICON_HEIGHT_RATIO]];

            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:button attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
            
            [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:button attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
            [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired];
        }
        
        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_infoButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_dateLabel attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_replyOrEditButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_infoButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageActionsButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_replyOrEditButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_GAP]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];

        [_uncollapsedHeaderConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_messageActionsButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN]];
        [_uncollapsedHeaderConstraints.lastObject setPriority:NSLayoutPriorityRequired-2];
    }

    NSAssert(_collapsedHeaderConstraint != nil, @"_collapsedHeaderConstraint is nil");
    [view removeConstraint:_collapsedHeaderConstraint];

    [view addSubview:_infoButton];
    [view addSubview:_replyOrEditButton];
    [view addSubview:_messageActionsButton];
    [view addConstraints:_uncollapsedHeaderConstraints];

    [_messageBodyPreviewField setHidden:YES];

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
    [_replyOrEditButton removeFromSuperview];
    [_messageActionsButton removeFromSuperview];

    [view addConstraint:_collapsedHeaderConstraint];
    
    [_messageBodyPreviewField setHidden:NO];
    
    _fullHeaderShown = NO;
}

#pragma mark Actions

- (void)editDraft:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SMMessage *m = _currentMessage;
    
    Boolean plainText = NO; // TODO: detect if the draft being opened is a plain text message, see issue #89
    [[appDelegate appController] openMessageEditorWindow:m.htmlBodyRendering plainText:plainText subject:m.subject to:m.toAddressList cc:m.ccAddressList bcc:nil draftUid:m.uid mcoAttachments:m.attachments];
}

- (void)discardDraft:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

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

- (void)composeReplyOrReplyAll:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    if([[appDelegate preferencesController] defaultReplyAction] == SMDefaultReplyAction_ReplyAll) {
        [self composeReplyAll:sender];
    }
    else {
        [self composeReply:sender];
    }
}

- (void)composeReply:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:_enclosingThreadCell replyKind:@"Reply" toAddress:nil];
}

- (void)composeReplyAll:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:_enclosingThreadCell replyKind:@"ReplyAll" toAddress:nil];
}

- (void)composeForward:(id)sender {
    [SMNotificationsController localNotifyComposeMessageReply:_enclosingThreadCell replyKind:@"Forward" toAddress:nil];
}

- (void)deleteMessage:(id)sender {
    [SMNotificationsController localNotifyDeleteMessage:_enclosingThreadCell];
}

- (void)changeMessageUnreadFlag:(id)sender {
    [SMNotificationsController localNotifyChangeMessageUnreadFlag:_enclosingThreadCell];
}

- (void)changeMessageFlaggedFlag:(id)sender {
    [SMNotificationsController localNotifyChangeMessageFlaggedFlag:_enclosingThreadCell];
}

- (void)saveAttachments:(id)sender {
    [SMNotificationsController localNotifySaveAttachments:_enclosingThreadCell];
}

- (void)saveAttachmentsToDownloads:(id)sender {
    [SMNotificationsController localNotifySaveAttachmentsToDownloads:_enclosingThreadCell];
}

- (void)showMessageActions:(id)sender {
    NSMenu *theMenu = [[NSMenu alloc] init];

    [theMenu setAutoenablesItems:NO];

    if(_currentMessage && _currentMessage.draft) {
        [[theMenu addItemWithTitle:@"Edit draft" action:@selector(editDraft:) keyEquivalent:@""] setTarget:self];
        [theMenu addItem:[NSMenuItem separatorItem]];
        [[theMenu addItemWithTitle:@"Discard draft" action:@selector(discardDraft:) keyEquivalent:@""] setTarget:self];
    }
    else {
        [[theMenu addItemWithTitle:@"Reply" action:@selector(composeReply:) keyEquivalent:@""] setTarget:self];
        [[theMenu addItemWithTitle:@"Reply All" action:@selector(composeReplyAll:) keyEquivalent:@""] setTarget:self];
        [[theMenu addItemWithTitle:@"Forward" action:@selector(composeForward:) keyEquivalent:@""] setTarget:self];
        [theMenu addItem:[NSMenuItem separatorItem]];
        [[theMenu addItemWithTitle:@"Delete" action:@selector(deleteMessage:) keyEquivalent:@""] setTarget:self];

        if(![_currentMessage isKindOfClass:[SMOutgoingMessage class]]) {
            [theMenu addItem:[NSMenuItem separatorItem]];
            
            [[theMenu addItemWithTitle:(_currentMessage.unseen? @"Mark as Read" : @"Mark as Unread") action:@selector(changeMessageUnreadFlag:) keyEquivalent:@""] setTarget:self];
        }
    }
    
    if(_currentMessage.hasAttachments) {
        [theMenu addItem:[NSMenuItem separatorItem]];
        [[theMenu addItemWithTitle:@"Save Attachments To..." action:@selector(saveAttachments:) keyEquivalent:@""] setTarget:self];
        [[theMenu addItemWithTitle:@"Save Attachments To Downloads" action:@selector(saveAttachmentsToDownloads:) keyEquivalent:@""] setTarget:self];
    }
    
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
