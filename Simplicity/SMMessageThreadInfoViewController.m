//
//  SMMessageThreadInfoViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMImageRegistry.h"
#import "SMFolder.h"
#import "SMFolderColorController.h"
#import "SMMessageThreadAccountProxy.h"
#import "SMMailbox.h"
#import "SMAccountMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThread.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageThreadInfoViewController.h"

@implementation SMMessageThreadInfoViewController {
    SMMessageThread *_messageThread;
/*
    NSButton *_starButton;
*/
    NSTextField *_subject;
    NSMutableArray *_colorLabels;
    NSMutableArray *_colorLabelConstraints;
    NSButton *_prevMessageButton;
    NSButton *_nextMessageButton;
    NSButton *_collapseAllButton;
    NSButton *_uncollapseAllButton;
    NSMutableArray *_collapseButtonsConstraints;
    NSLayoutConstraint *_subjectTrailingConstraint;
}

+ (NSTextField*)createColorLabel:(NSString*)text color:(NSColor*)color {
    NSTextField *label = [[NSTextField alloc] init];
    
    [label setStringValue:text];
    [label setBordered:YES];
    [label setBezeled:NO];
    [label setBackgroundColor:color];
    [label setDrawsBackground:YES];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFrameSize:[label fittingSize]];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    
    const NSUInteger fontSize = 12;
    [label setFont:[NSFont systemFontOfSize:fontSize]];
    
    return label;
}

- (id)init {
    self = [super init];
    
    if(self) {
        NSView *view = [[NSView alloc] init];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self setView:view];
        [self initSubviews];
    }
    
    return self;
}

- (void)setMessageThread:(SMMessageThread*)messageThread {
    if(_messageThread == messageThread)
        return;
/*
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    if(_messageThread.flagged) {
        _starButton.image = appDelegate.imageRegistry.yellowStarImage;
    } else {
        _starButton.image = appDelegate.imageRegistry.grayStarImage;
    }
*/

    _messageThread = messageThread;

    [_subject setStringValue:(messageThread != nil? [[messageThread.messagesSortedByDate firstObject] subject] : @"")];
    
    [self updateLayout];
}

#define H_MARGIN 6
#define V_MARGIN 10
#define FROM_W 5
#define H_GAP 5
#define V_GAP 10

+ (NSUInteger)infoHeaderHeight {
    return [SMMessageDetailsViewController messageDetaisHeaderHeight]+1;
}

- (void)initSubviews {
    NSView *view = [self view];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:0 constant:[SMMessageThreadInfoViewController infoHeaderHeight]]];
    
    // star
/*
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    _starButton = [[NSButton alloc] init];
    _starButton.translatesAutoresizingMaskIntoConstraints = NO;
    _starButton.bezelStyle = NSShadowlessSquareBezelStyle;
    _starButton.target = self;
    _starButton.image = appDelegate.imageRegistry.grayStarImage;
    [_starButton.cell setImageScaling:NSImageScaleProportionallyDown];
    _starButton.bordered = NO;
    _starButton.action = @selector(toggleFullDetails:);

    [view addSubview:_starButton];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController headerHeight]/[SMMessageDetailsViewController headerIconHeightRatio]]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_starButton attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];
*/
    
    // subject

    _subject = [SMMessageDetailsViewController createLabel:@"" bold:YES];
    _subject.textColor = [NSColor blackColor];
    
    [_subject.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    [_subject setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-2 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    [view addSubview:_subject];
    
/*
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
*/

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_subject attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:view attribute:NSLayoutAttributeRight multiplier:1.0 constant:-H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

    // prev message
    
    _prevMessageButton = [[NSButton alloc] init];
    _prevMessageButton.translatesAutoresizingMaskIntoConstraints = NO;
    _prevMessageButton.bezelStyle = NSShadowlessSquareBezelStyle;
    _prevMessageButton.target = self;
    _prevMessageButton.image = [NSImage imageNamed:@"Button-Up-128.png"];
    [_prevMessageButton.cell setImageScaling:NSImageScaleProportionallyDown];
    _prevMessageButton.bordered = NO;
    _prevMessageButton.action = @selector(uncollapseAllCells:);

    // next message

    _nextMessageButton = [[NSButton alloc] init];
    _nextMessageButton.translatesAutoresizingMaskIntoConstraints = NO;
    _nextMessageButton.bezelStyle = NSShadowlessSquareBezelStyle;
    _nextMessageButton.target = self;
    _nextMessageButton.image = [NSImage imageNamed:@"Button-Down-128.png"];
    [_nextMessageButton.cell setImageScaling:NSImageScaleProportionallyDown];
    _nextMessageButton.bordered = NO;
    _nextMessageButton.action = @selector(uncollapseAllCells:);
    
    // uncollapse all

    _uncollapseAllButton = [[NSButton alloc] init];
    _uncollapseAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    _uncollapseAllButton.bezelStyle = NSShadowlessSquareBezelStyle;
    _uncollapseAllButton.target = self;
    _uncollapseAllButton.image = [NSImage imageNamed:@"uncollapse-all.png"];
    [_uncollapseAllButton.cell setImageScaling:NSImageScaleProportionallyDown];
    _uncollapseAllButton.bordered = NO;
    _uncollapseAllButton.action = @selector(uncollapseAllCells:);

    // collapse all

    _collapseAllButton = [[NSButton alloc] init];
    _collapseAllButton.translatesAutoresizingMaskIntoConstraints = NO;
    _collapseAllButton.bezelStyle = NSShadowlessSquareBezelStyle;
    _collapseAllButton.target = self;
    _collapseAllButton.image = [NSImage imageNamed:@"collapse-all.png"];
    [_collapseAllButton.cell setImageScaling:NSImageScaleProportionallyDown];
    _collapseAllButton.bordered = NO;
    _collapseAllButton.action = @selector(collapseAllCells:);

    // constraints: uncollapse button

    _collapseButtonsConstraints = [NSMutableArray array];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_uncollapseAllButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/2.5]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_uncollapseAllButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_uncollapseAllButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_uncollapseAllButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_uncollapseAllButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN]];
    
    // constraints: collapse button
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_collapseAllButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/2.5]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_collapseAllButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_collapseAllButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];

    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_collapseAllButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_collapseAllButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_uncollapseAllButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
    
    // constraints: next message
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_nextMessageButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/2.5]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_nextMessageButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_nextMessageButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_nextMessageButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_nextMessageButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_collapseAllButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];

    // constraints: prev message
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_prevMessageButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:[SMMessageDetailsViewController messageDetaisHeaderHeight]/2.5]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_prevMessageButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_prevMessageButton attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0]];
    
    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_prevMessageButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

    [_collapseButtonsConstraints addObject:[NSLayoutConstraint constraintWithItem:_prevMessageButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_nextMessageButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
}

- (void)updateMessageThread {
    if(_messageThread == nil)
        return;

    [self updateLayout];
}

- (void)updateLayout {
    NSView *view = [self view];

    [view removeConstraint:_subjectTrailingConstraint];
    
    if(_messageThread.messagesCount == 1) {
        [view removeConstraints:_collapseButtonsConstraints];
        
        [_prevMessageButton removeFromSuperview];
        [_nextMessageButton removeFromSuperview];
        [_collapseAllButton removeFromSuperview];
        [_uncollapseAllButton removeFromSuperview];
    }
    else {
        [view addSubview:_prevMessageButton];
        [view addSubview:_nextMessageButton];
        [view addSubview:_collapseAllButton];
        [view addSubview:_uncollapseAllButton];
        
        [view addConstraints:_collapseButtonsConstraints];
    }

    // TODO: reuse labels for speed
    if(_colorLabels != nil) {
        NSAssert(_colorLabelConstraints != nil, @"_colorLabelConstraints == nil");

        [view removeConstraints:_colorLabelConstraints];
        
        for(NSTextField *label in _colorLabels)
            [label removeFromSuperview];
        
        [_colorLabels removeAllObjects];
        [_colorLabelConstraints removeAllObjects];
    } else {
        NSAssert(_colorLabelConstraints == nil, @"_colorLabelConstraints != nil");

        _colorLabels = [NSMutableArray array];
        _colorLabelConstraints = [NSMutableArray array];
    }

    if(_messageThread == nil)
        return;

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *currentFolder = [appDelegate.currentMailboxController selectedFolder];
    
    NSMutableArray *labels = [NSMutableArray array];
    NSArray *colors = [appDelegate.messageThreadAccountProxy colorsForMessageThread:_messageThread folder:currentFolder labels:labels];

    NSAssert(labels.count == colors.count, @"labels count %lu != colors count %lu", labels.count, colors.count);
    
    for(NSUInteger i = 0; i < labels.count; i++) {
        NSTextField *labelView = [SMMessageThreadInfoViewController createColorLabel:labels[i] color:colors[i]];
        [labelView setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-3 forOrientation:NSLayoutConstraintOrientationHorizontal];

        [view addSubview:labelView];

        if(i == 0) {
            [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:_subject attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        } else {
            [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:_colorLabels.lastObject attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP/2]];
        }

        [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

        [_colorLabels addObject:labelView];
    }

    [view addConstraints:_colorLabelConstraints];

    if(_messageThread.messagesCount > 1) {
        _subjectTrailingConstraint = [NSLayoutConstraint constraintWithItem:(_colorLabels.count != 0? _colorLabels.lastObject : _subject) attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_collapseAllButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP];
    }
    else {
        _subjectTrailingConstraint = [NSLayoutConstraint constraintWithItem:(_colorLabels.count != 0? _colorLabels.lastObject : _subject) attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:view attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN];
    }
    
    _subjectTrailingConstraint.priority = NSLayoutPriorityDefaultLow;
    
    [view addConstraint:_subjectTrailingConstraint];
}

- (void)collapseAllCells:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] messageThreadViewController] collapseAll];
}

- (void)uncollapseAllCells:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] messageThreadViewController] uncollapseAll];
}

@end
