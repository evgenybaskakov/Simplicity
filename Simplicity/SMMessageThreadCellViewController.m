//
//  SMMessageThreadCellViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/24/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMBoxView.h"
#import "SMAttachmentItem.h"
#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageBodyViewController.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadCellViewController.h"

static const NSUInteger MIN_BODY_HEIGHT = 150;

@implementation SMMessageThreadCellViewController {
    SMMessage *_message;
    SMMessageDetailsViewController *_messageDetailsViewController;
    SMMessageBodyViewController *_messageBodyViewController;
    SMAttachmentsPanelViewController *_attachmentsPanelViewController;
    NSView *_messageView;
    NSButton *_headerButton;
    NSProgressIndicator *_progressIndicator;
    NSLayoutConstraint *_mesageBottomConstraint;
    NSLayoutConstraint *_messageBodyHeightConstraint;
    NSLayoutConstraint *_messageDetailsCollapsedBottomConstraint;
    NSLayoutConstraint *_attachmentsPanelViewHeightConstraint;
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
        
        _boxView = [[SMBoxView alloc] init];
        _boxView.drawTop = YES;
        _boxView.leftTopInset = 31;
        _boxView.boxColor = [NSColor colorWithCalibratedWhite:0.9 alpha:1];
        _boxView.fillColor = [NSColor whiteColor];
        _boxView.mouseInColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1];
        _boxView.translatesAutoresizingMaskIntoConstraints = NO;

        // init header button

        _headerButton = [[NSButton alloc] init];
        _headerButton.translatesAutoresizingMaskIntoConstraints = NO;
        _headerButton.bezelStyle = NSShadowlessSquareBezelStyle;
        _headerButton.target = self;
        _headerButton.action = @selector(headerButtonClicked:);
        _headerButton.title = @"";

        [_headerButton setTransparent:YES];
        [_headerButton setEnabled:NO];

        [_boxView addSubview:_headerButton];

        [self addConstraint:_headerButton constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:0 constant:[SMMessageThreadCellViewController collapsedCellHeight]] priority:NSLayoutPriorityRequired];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_headerButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];

        // init message details view
        
        _messageDetailsViewController = [[SMMessageDetailsViewController alloc] init];
        
        NSView *messageDetailsView = [ _messageDetailsViewController view ];
        NSAssert(messageDetailsView, @"messageDetailsView");
        
        [_boxView addSubview:messageDetailsView];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow];
        
        [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:messageDetailsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0] priority:NSLayoutPriorityRequired];
    
        _messageDetailsCollapsedBottomConstraint = [NSLayoutConstraint constraintWithItem:messageDetailsView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];

        [_messageDetailsViewController setEnclosingThreadCell:self];
        
        // commit the main view
        
        [self setView:_boxView];

        // now set the view constraints depending on the desired states

        _collapsed = !collapsed;

        [self toggleCollapse];
        
        _cellInitialized = YES;
        
        // Register observed events

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachmentsPanelViewHeightChanged:) name:@"SMAttachmentsPanelViewHeightChanged" object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSUInteger)cellHeaderHeight {
    return _messageDetailsViewController.view.frame.size.height;
}

- (void)attachmentsPanelViewHeightChanged:(NSNotification*)notification {
    SMAttachmentsPanelViewController *attachmentsPanelViewController = [[notification userInfo] objectForKey:@"Object"];

    if(_attachmentsPanelViewController == attachmentsPanelViewController) {
        NSUInteger newAttachmentsPanelHeight = [_attachmentsPanelViewController intrinsicContentViewSize].height;
        
        if(newAttachmentsPanelHeight != _attachmentsPanelViewHeightConstraint.constant) {
            [_boxView removeConstraint:_attachmentsPanelViewHeightConstraint];

            _attachmentsPanelViewHeightConstraint = [NSLayoutConstraint constraintWithItem:_attachmentsPanelViewController.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:newAttachmentsPanelHeight];
            
            [_boxView addConstraint:_attachmentsPanelViewHeightConstraint];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageThreadCellHeightChanged" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"ThreadCell", nil]];
        }
    }
}

- (void)showProgressIndicator {
    if(_progressIndicator == nil) {
        _progressIndicator = [[NSProgressIndicator alloc] init];
        _progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        
        [_progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
        [_progressIndicator setDisplayedWhenStopped:NO];
        [_progressIndicator startAnimation:self];
    }
    
    [_boxView addSubview:_progressIndicator];
    
    [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_progressIndicator attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow-1];
    
    [self addConstraint:_boxView constraint:[NSLayoutConstraint constraintWithItem:_progressIndicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_boxView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0] priority:NSLayoutPriorityDefaultLow-1];
}

- (void)hideProgressIndicator {
    [_progressIndicator removeFromSuperview];
}

- (void)enableCollapse:(Boolean)enable {
    [_headerButton setEnabled:enable];
}

- (void)addConstraint:(NSView*)view constraint:(NSLayoutConstraint*)constraint priority:(NSLayoutPriority)priority {
    constraint.priority = priority;
    [view addConstraint:constraint];
}

+ (NSUInteger)collapsedCellHeight {
    return [SMMessageDetailsViewController messageDetaisHeaderHeight];
}

- (void)setCollapsed:(Boolean)collapsed {
    // When the collapse property changes, it also adds/removes subviews and constraints.
    // The added constraints may conflict with the autoresizing frame
    // which is set previously, when the message thread cells layout is set.
    // Therefore, to avoid different heights conflict, just make the height flexible.
    // After collapsing/uncollapsing, the following message thread cell update
    // procedure will choose the right frame and the autoresizing mask anyway.
    _boxView.autoresizingMask |= NSViewHeightSizable;
    
    if(collapsed) {
        if(_collapsed)
            return;
        
        if(_attachmentsPanelShown) {
            NSAssert(_attachmentsPanelViewConstraints != nil, @"_attachmentsPanelViewConstraints not created");

            [_boxView removeConstraints:_attachmentsPanelViewConstraints];
            [_boxView removeConstraint:_attachmentsPanelViewHeightConstraint];
            
            [_attachmentsPanelViewController.view removeFromSuperview];
            
            _attachmentsPanelShown = NO;
        }
        
        [_messageDetailsViewController collapse];
        
//        _boxView.fillColor = [NSColor colorWithCalibratedRed:0.96 green:0.96 blue:0.96 alpha:1.0];
        _boxView.drawBottom = _shouldDrawBottomLineWhenCollapsed;
        _boxView.trackMouse = YES;
        
        [self hideProgressIndicator];
        
        if(_messageBodyViewController != nil) {
            [_messageBodyViewController.view removeFromSuperview];
        }
        
        NSAssert(_messageDetailsCollapsedBottomConstraint != nil, @"_messageDetailsCollapsedBottomConstraint not created");
        [_boxView addConstraint:_messageDetailsCollapsedBottomConstraint];
        
        _collapsed = YES;
    } else {
        if(!_collapsed)
            return;

        // Setup the message body view controller
        
        if(_messageBodyViewController == nil) {
            _messageBodyViewController = [[SMMessageBodyViewController alloc] init];
            
            NSView *messageBodyView = [_messageBodyViewController view];
            NSAssert(messageBodyView, @"messageBodyView");

            // The message body web view doesn't have a frame yet, but it's going to load an html body.
            // If the body is loaded imminently, before the width contraints trigger a new geometry,
            // the height of the web frame will be calculated based on its current width, which is
            // by default set to 0. Usually that will result in a huge height which will most likely
            // ruin the message thread layout.
            // To prevent that from happening, forcely set the already known web body view width.
            // Future body height will be calculated based on it.
            [messageBodyView setFrameSize:_boxView.frame.size];
            
            // Add the view to the superview immediately to have the height calculation take effect.
            [_boxView addSubview:messageBodyView];

            // The cell view is added to the superview, so now we can adjust its height.
            [self adjustCellHeightToFitContentResizeable:NO];
            
            if(_htmlText != nil) {
                // this means that the message html text was set before,
                // when there was no body view
                // so show it now
                [self setMessageBody];
            }
        }

        // Setup body constraints

        [_boxView removeConstraint:_messageDetailsCollapsedBottomConstraint];
        
        NSView *messageBodyView = [_messageBodyViewController view];
        NSAssert(messageBodyView, @"messageBodyView");

        [_boxView addSubview:messageBodyView];
        
        [_boxView addConstraint:[NSLayoutConstraint constraintWithItem:_messageDetailsViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        
        [_boxView addConstraint:[NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
        
        [_boxView addConstraint:[NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];

        _mesageBottomConstraint = [NSLayoutConstraint constraintWithItem:_boxView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:messageBodyView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
        
        [_boxView addConstraint:_mesageBottomConstraint];

        // Set view internals
        
        _boxView.fillColor = [NSColor whiteColor];
        _boxView.drawBottom = _shouldDrawBottomLineWhenUncollapsed;
        _boxView.trackMouse = NO;

        [_messageDetailsViewController uncollapse];
        [_messageBodyViewController uncollapse];
        
        if(_htmlText == nil) {
            [self showProgressIndicator];
        }
    
        [self showAttachmentsPanel];

        _collapsed = NO;
    }

    if(_cellInitialized) {
        [_messageThreadViewController setCellCollapsed:_collapsed cellIndex:_cellIndex];
    }
}

- (void)setShouldDrawBottomLineWhenCollapsed:(Boolean)shouldDrawBottomLineWhenCollapsed {
    _shouldDrawBottomLineWhenCollapsed = shouldDrawBottomLineWhenCollapsed;
    
    if(_collapsed) {
        _boxView.drawBottom = _shouldDrawBottomLineWhenCollapsed;
    }
}

- (void)setShouldDrawBottomLineWhenUncollapsed:(Boolean)shouldDrawBottomLineWhenUncollapsed {
    _shouldDrawBottomLineWhenUncollapsed = shouldDrawBottomLineWhenUncollapsed;
    
    if(!_collapsed) {
        _boxView.drawBottom = _shouldDrawBottomLineWhenUncollapsed;
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

- (NSUInteger)messageBodyHeight {
    return MAX(MIN_BODY_HEIGHT, [_messageBodyViewController contentHeight]);
}

- (NSUInteger)cellHeight {
    if(_collapsed) {
        return [SMMessageDetailsViewController messageDetaisHeaderHeight];
    }
    else {
        const NSUInteger detailsHeight = [_messageDetailsViewController intrinsicContentViewSize].height;
        const NSUInteger bodyHeight = [self messageBodyHeight];
        const NSUInteger attachmentsHeight = (_attachmentsPanelViewController != nil?
                                              [_attachmentsPanelViewController intrinsicContentViewSize].height : 0);
        
        return detailsHeight + bodyHeight + attachmentsHeight;
    }
}

- (void)adjustCellHeightToFitContentResizeable:(Boolean)heightResizeable {
    NSView *messageBodyView = [_messageBodyViewController view];
    NSAssert(messageBodyView, @"messageBodyView");

    NSUInteger contentHeight = [self messageBodyHeight];
    SM_LOG_DEBUG(@"contentHeight: %lu", contentHeight);

    if(_messageBodyHeightConstraint != nil) {
        [_boxView removeConstraint:_messageBodyHeightConstraint];
        _messageBodyHeightConstraint = nil;
    }

    if(!heightResizeable) {
        //
        // Unless requested otherwise, make the message body fixed.
        //
        if(_mesageBottomConstraint != nil) {
            [_boxView removeConstraint:_mesageBottomConstraint];
            _mesageBottomConstraint = nil;
        }
        
        _messageBodyHeightConstraint = [NSLayoutConstraint constraintWithItem:messageBodyView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:contentHeight];

        [_boxView addConstraint:_messageBodyHeightConstraint];

    }
}

- (void)headerButtonClicked:(id)sender {
    [self toggleCollapse];

    [_messageThreadViewController updateCellFrames];
}

- (void)showAttachmentsPanel {
    if(_message.attachments.count == 0) {
        return;
    }

    if(_attachmentsPanelShown) {
        return;
    }

    NSView *view = [self view];
    NSAssert(view != nil, @"view is nil");

    if(_attachmentsPanelViewController == nil) {
        _attachmentsPanelViewController = [[SMAttachmentsPanelViewController alloc] initWithNibName:@"SMAttachmentsPanelViewController" bundle:nil];
        
        NSView *attachmentsView = _attachmentsPanelViewController.view;
        NSAssert(attachmentsView, @"attachmentsView");
        
        attachmentsView.translatesAutoresizingMaskIntoConstraints = NO;
        
        NSAssert(_attachmentsPanelViewConstraints == nil, @"_attachmentsPanelViewConstraints already created");
        _attachmentsPanelViewConstraints = [NSMutableArray array];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:_messageBodyViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        
        // TODO: this is a workaround for cell height and message body height not being matched
        ((NSLayoutConstraint*)_attachmentsPanelViewConstraints.lastObject).priority = NSLayoutPriorityDefaultLow;
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
        
        [_attachmentsPanelViewConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:attachmentsView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];

        _attachmentsPanelViewHeightConstraint = [NSLayoutConstraint constraintWithItem:attachmentsView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[_attachmentsPanelViewController intrinsicContentViewSize].height];

        // bind the message with the the attachment panel
        [_attachmentsPanelViewController setMessage:_message];
    }

    [view addSubview:_attachmentsPanelViewController.view];

    [view addConstraints:_attachmentsPanelViewConstraints];
    [view addConstraint:_attachmentsPanelViewHeightConstraint];

    _attachmentsPanelShown = YES;
}

- (void)setMessageBody {
    NSAssert(_message != nil, @"_message is nil");
    NSAssert(_messageBodyViewController != nil, @"not message body view controller");
        
    NSView *messageBodyView = [_messageBodyViewController view];
    NSAssert(messageBodyView, @"messageBodyView");
    
    SMMessageThread *messageThread = _messageThreadViewController.currentMessageThread;
    SMUserAccount *account = (SMUserAccount*)messageThread.account;
    
    [_messageBodyViewController setMessageHtmlText:_htmlText messageId:_message.messageId folder:_message.remoteFolder account:account];
    
    if(_progressIndicator != nil) {
        [_progressIndicator stopAnimation:self];

        [self hideProgressIndicator];

        _progressIndicator = nil;
    }
    
    if(!_collapsed) {
        [self showAttachmentsPanel];
    }
}

- (Boolean)loadMessageBody {
    NSAssert(_message != nil, @"no message set");

    if(_htmlText != nil)
        return TRUE;

    _htmlText = [_message htmlBodyRendering];
    
    if(_htmlText == nil) {
        return FALSE;
    }

    if(_messageBodyViewController != nil) {
        [self setMessageBody];
    }

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

#pragma mark Saving attachments

- (void)saveAttachments {
    [_attachmentsPanelViewController saveAllAttachments];
}

- (void)saveAttachmentsToDownloads {
    [_attachmentsPanelViewController saveAllAttachmentsToDownloads];
}

#pragma mark Finding contents

- (NSUInteger)stringOccurrencesCount {
    return _messageBodyViewController.stringOccurrencesCount;
}

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase {
    [_messageBodyViewController highlightAllOccurrencesOfString:str matchCase:matchCase];
}

- (NSInteger)markOccurrenceOfFoundString:(NSUInteger)index {
    return [_messageBodyViewController markOccurrenceOfFoundString:index];
}

- (void)removeMarkedOccurrenceOfFoundString {
    [_messageBodyViewController removeMarkedOccurrenceOfFoundString];
}

- (void)removeAllHighlightedOccurrencesOfString {
    [_messageBodyViewController removeAllHighlightedOccurrencesOfString];
}

@end
