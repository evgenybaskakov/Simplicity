//
//  SMMessageThreadCellViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/24/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMBoxView.h"
#import "SMAttachmentItem.h"
#import "SMMessage.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageBodyViewController.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadCellViewController.h"

static const NSUInteger MIN_BODY_HEIGHT = 150;

@implementation SMMessageThreadCellViewController {
    SMBoxView *_view;
	SMMessage *_message;
	SMMessageDetailsViewController *_messageDetailsViewController;
	SMMessageBodyViewController *_messageBodyViewController;
	SMAttachmentsPanelViewController *_attachmentsPanelViewController;
	NSView *_messageView;
	NSButton *_headerButton;
	NSProgressIndicator *_progressIndicator;
	NSLayoutConstraint *_messageDetailsBottomConstraint;
	NSLayoutConstraint *_messageBodyBottomConstraint;
	NSMutableArray *_attachmentsPanelViewConstraints;
	CGFloat _messageViewHeight;
	NSString *_htmlText;
	Boolean _messageTextIsSet;
	Boolean _attachmentsPanelShown;
	Boolean _cellInitialized;
}

- (id)init:(SMMessageThreadViewController*)messageThreadViewController collapsed:(Boolean)collapsed {
	self = [super init];
	
	if(self) {
        _messageThreadViewController = messageThreadViewController;

		// init main view
		
		_view = [[SMBoxView alloc] init];
        _view.drawTop = YES;
        _view.boxColor = [NSColor lightGrayColor];
		_view.translatesAutoresizingMaskIntoConstraints = NO;

		// init header button

		_headerButton = [[NSButton alloc] init];
		_headerButton.translatesAutoresizingMaskIntoConstraints = NO;
		_headerButton.bezelStyle = NSShadowlessSquareBezelStyle;
		_headerButton.target = self;
		_headerButton.action = @selector(headerButtonClicked:);

		[_headerButton setTransparent:YES];
		[_headerButton setEnabled:NO];

		[_view addSubview:_headerButton];

		[self addConstraint:_headerButton constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:0 constant:[SMMessageThreadCellViewController collapsedCellHeight]] priority:NSLayoutPriorityRequired];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];

		// init message details view
		
		_messageDetailsViewController = [[SMMessageDetailsViewController alloc] init];
		
		NSView *messageDetailsView = [ _messageDetailsViewController view ];
		NSAssert(messageDetailsView, @"messageDetailsView");
		
		[_view addSubview:messageDetailsView];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow];
		
		[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
	
		_messageDetailsBottomConstraint = [NSLayoutConstraint constraintWithItem:messageDetailsView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];

		[_messageDetailsViewController setEnclosingThreadCell:self];
		
		// commit the main view
		
		[self setView:_view];

		// now set the view constraints depending on the desired states

		_collapsed = !collapsed;

		[self toggleCollapse];
		
		_cellInitialized = YES;
	}
	
	return self;
}

- (void)initProgressIndicator {
	NSAssert(_progressIndicator == nil, @"progress indicator already created");
	
	_progressIndicator = [[NSProgressIndicator alloc] init];
	_progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
	
	[_progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
	[_progressIndicator setDisplayedWhenStopped:NO];
	[_progressIndicator startAnimation:self];
	
	NSView *view = [self view];
	
	[view addSubview:_progressIndicator];
	
	[self addConstraint:view constraint:[NSLayoutConstraint constraintWithItem:_progressIndicator attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:[_messageBodyViewController view] attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow-1];
	
	[self addConstraint:view constraint:[NSLayoutConstraint constraintWithItem:_progressIndicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:[_messageBodyViewController view] attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow-1];
}

- (void)enableCollapse:(Boolean)enable {
	[_headerButton setEnabled:enable];
}

- (void)addConstraint:(NSView*)view constraint:(NSLayoutConstraint*)constraint priority:(NSLayoutPriority)priority {
	constraint.priority = priority;
	[view addConstraint:constraint];
}

+ (NSUInteger)collapsedCellHeight {
	return [SMMessageDetailsViewController headerHeight];
}

- (void)setCollapsed:(Boolean)collapsed {
	if(collapsed) {
		if(_collapsed)
			return;
		
		[self hideAttachmentsPanel];
		
		[_messageDetailsViewController collapse];
        
        _view.fillColor = [NSColor colorWithCalibratedRed:0.96 green:0.96 blue:0.96 alpha:1.0];
        _view.drawBottom = YES;
        
        [_progressIndicator setHidden:YES];
		
		_collapsed = YES;
	} else {
		if(!_collapsed)
			return;
		
		if(_messageBodyViewController == nil) {
			[_view removeConstraint:_messageDetailsBottomConstraint];
			
			_messageBodyViewController = [[SMMessageBodyViewController alloc] init];
			
			NSView *messageBodyView = [_messageBodyViewController view];
			NSAssert(messageBodyView, @"messageBodyView");
			
			[_view addSubview:messageBodyView];
			
			[_view addConstraint:[NSLayoutConstraint constraintWithItem:_messageDetailsViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
			
			[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
			
			[_view addConstraint:[NSLayoutConstraint constraintWithItem:_view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
			
			[self addConstraint:_view constraint:[NSLayoutConstraint constraintWithItem:messageBodyView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:0 multiplier:1.0 constant:[_messageBodyViewController contentHeight]] priority:NSLayoutPriorityDefaultLow];
			
			NSAssert(_messageBodyBottomConstraint == nil, @"_messageBodyBottomConstraint already created");
			_messageBodyBottomConstraint = [NSLayoutConstraint constraintWithItem:messageBodyView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-1];
			
			[_view addConstraint:_messageBodyBottomConstraint];
			
			if(_htmlText != nil) {
				// this means that the message html text was set before,
				// when there was no body view
				// so show it now
				[self showMessageBody];
			}
		}
		
        _view.fillColor = [NSColor whiteColor];
        _view.drawBottom = _shouldDrawBottomLineWhenUncollapsed;

        [_messageDetailsViewController uncollapse];
		[_messageBodyViewController uncollapse];
		
		if(_htmlText == nil) {
			if(_progressIndicator == nil) {
				[self initProgressIndicator];
			} else {
				[_progressIndicator setHidden:NO];
			}
		}
		
		_collapsed = NO;
	}

	if(_cellInitialized) {
		[_messageThreadViewController setCellCollapsed:_collapsed cellIndex:_cellIndex];
	}
}

- (void)setShouldDrawBottomLineWhenUncollapsed:(Boolean)shouldDrawBottomLineWhenUncollapsed {
    _shouldDrawBottomLineWhenUncollapsed = shouldDrawBottomLineWhenUncollapsed;
    
    if(!_collapsed) {
        _view.drawBottom = _shouldDrawBottomLineWhenUncollapsed;
    }
}

- (Boolean)isCollapsed {
	return _collapsed;
}

- (void)toggleCollapse {
	if(!_collapsed) {
		[self setCollapsed:YES];
	} else {
		[self setCollapsed:NO];
	}
}

- (NSUInteger)cellHeight {
    if(_collapsed) {
        return [SMMessageDetailsViewController headerHeight];
    }
    else {
        return [SMMessageDetailsViewController headerHeight] + [_messageDetailsViewController intrinsicContentViewSize].height + MAX(MIN_BODY_HEIGHT, [_messageBodyViewController contentHeight]);
    }
}

- (void)headerButtonClicked:(id)sender {
	[self toggleCollapse];

	[_messageThreadViewController updateCellFrames];
}

- (void)toggleAttachmentsPanel {
	if(!_attachmentsPanelShown) {
		[self showAttachmentsPanel];
	} else {
		[self hideAttachmentsPanel];
	}
}

- (void)showAttachmentsPanel {
	if(_attachmentsPanelShown)
		return;

	NSView *view = [self view];
	NSAssert(view != nil, @"view is nil");

	NSAssert(_messageBodyBottomConstraint != nil, @"_messageBodyBottomConstraint not created");
	[view removeConstraint:_messageBodyBottomConstraint];
	
	if(_attachmentsPanelViewController == nil) {
		_attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
		
		NSView *attachmentsView = _attachmentsPanelViewController.view;
		NSAssert(attachmentsView, @"attachmentsView");
		
		NSAssert(_attachmentsPanelViewConstraints == nil, @"_attachmentsPanelViewConstraints already created");
		_attachmentsPanelViewConstraints = [NSMutableArray array];
		
		[_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
		
		[_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
		
		[_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
		
		[_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
		
		// bind the message with the the attachment panel
        [_attachmentsPanelViewController setMessage:_message];
	}

	[view addSubview:_attachmentsPanelViewController.view];
	[view addConstraints:_attachmentsPanelViewConstraints];

	_attachmentsPanelShown = YES;
}

- (void)hideAttachmentsPanel {
	if(!_attachmentsPanelShown)
		return;

	NSView *view = [self view];
	NSAssert(view != nil, @"view is nil");

	NSAssert(_attachmentsPanelViewConstraints != nil, @"_attachmentsPanelViewConstraints not created");
	[view removeConstraints:_attachmentsPanelViewConstraints];

	[_attachmentsPanelViewController.view removeFromSuperview];

	NSAssert(_messageBodyBottomConstraint != nil, @"_messageBodyBottomConstraint not created");
	[view addConstraint:_messageBodyBottomConstraint];

	_attachmentsPanelShown = NO;
}

- (void)showMessageBody {
	NSAssert(_messageBodyViewController != nil, @"not message body view controller");
		
	NSView *messageBodyView = [_messageBodyViewController view];
	NSAssert(messageBodyView, @"messageBodyView");
	
	[_messageBodyViewController setMessageHtmlText:_htmlText uid:_message.uid folder:[_message remoteFolder]];
	
	[_progressIndicator stopAnimation:self];
}

- (Boolean)loadMessageBody {
	NSAssert(_message != nil, @"no message set");

	if(_htmlText != nil)
		return TRUE;

	_htmlText = [_message htmlBodyRendering];
	
	if(_htmlText == nil)
		return FALSE;

	if(_messageBodyViewController != nil)
		[self showMessageBody];

	_messageTextIsSet = YES;
	
	return TRUE;
}

- (Boolean)mainFrameLoaded {
    return (_messageBodyViewController != nil) && _messageBodyViewController.mainFrameLoaded;
}

- (void)setMessage:(SMMessage*)message {
	NSAssert(_message == nil, @"message already set");

	_message = message;

	[_messageDetailsViewController setMessage:message];
}

- (void)updateMessage {
	[_messageDetailsViewController updateMessage];
}

#pragma mark Finding contents

- (NSUInteger)stringOccurrencesCount {
	return _messageBodyViewController.stringOccurrencesCount;
}

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase {
	[_messageBodyViewController highlightAllOccurrencesOfString:str matchCase:matchCase];
}

- (void)markOccurrenceOfFoundString:(NSUInteger)index {
	[_messageBodyViewController markOccurrenceOfFoundString:index];
}

- (void)removeMarkedOccurrenceOfFoundString {
	[_messageBodyViewController removeMarkedOccurrenceOfFoundString];
}

- (void)removeAllHighlightedOccurrencesOfString {
	[_messageBodyViewController removeAllHighlightedOccurrencesOfString];
}

@end
