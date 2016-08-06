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
#import "SMLabelWithCloseButton.h"

@implementation SMMessageThreadInfoViewController {
    SMMessageThread *_messageThread;
/*
    NSButton *_starButton;
*/
    NSTextField *_subject;
    NSButton *_addLabelButton;
    NSMutableArray<SMLabelWithCloseButton*> *_colorLabels;
    NSMutableArray<NSLayoutConstraint*> *_colorLabelConstraints;
    NSLayoutConstraint *_subjectTrailingConstraint;
}

- (SMLabelWithCloseButton*)createColorLabel:(NSString*)text color:(NSColor*)color object:(NSObject*)object {
    SMLabelWithCloseButton *label = [[SMLabelWithCloseButton alloc] initWithNibName:@"SMLabelWithCloseButton" bundle:nil];
    NSView *labelView = label.view;
    labelView.translatesAutoresizingMaskIntoConstraints = NO;
    
    label.text = text;
    label.color = color;
    label.object = object;
    label.target = self;
    label.action = @selector(removeLabel:);
    
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
    
    
    // add label button

    _addLabelButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
    _addLabelButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addLabelButton.image = [NSImage imageNamed:NSImageNameAddTemplate];
    _addLabelButton.bezelStyle = NSTexturedRoundedBezelStyle;
    _addLabelButton.toolTip = @"Add label";

    [view addSubview:_addLabelButton];
    
    // subject constraints
    
/*
    [view addConstraint:[NSLayoutConstraint constraintWithItem:_starButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
*/

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_subject attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_MARGIN]];

    // add button constaints

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_addLabelButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:24]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_addLabelButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1.0 constant:20]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_addLabelButton attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_addLabelButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:H_MARGIN]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:_subject attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_addLabelButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN]];
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
        // TODO: disable message navigation buttons in the toolbar
    }
    else {
        // TODO: enable message navigation buttons in the toolbar
    }

    // TODO: reuse labels for speed
    if(_colorLabels != nil) {
        NSAssert(_colorLabelConstraints != nil, @"_colorLabelConstraints == nil");

        [view removeConstraints:_colorLabelConstraints];
        
        for(SMLabelWithCloseButton *label in _colorLabels) {
            [label.view removeFromSuperview];
        }
        
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
        SMLabelWithCloseButton *label = [self createColorLabel:labels[i] color:colors[i] object:labels[i]];
        NSView *labelView = label.view;
        
        [labelView setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow-3 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [view addSubview:labelView];

        if(i == 0) {
            [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:_subject attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP]];
        } else {
            SMLabelWithCloseButton *lastLabel = _colorLabels.lastObject;
            [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:lastLabel.view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_GAP/2]];
        }

        [_colorLabelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:labelView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];

        [_colorLabels addObject:label];
    }

    [view addConstraints:_colorLabelConstraints];

    SMLabelWithCloseButton *lastLabel = _colorLabels.lastObject;
    _subjectTrailingConstraint = [NSLayoutConstraint constraintWithItem:(_colorLabels.count != 0? lastLabel.view : _subject) attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:_addLabelButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-H_MARGIN];
    
    _subjectTrailingConstraint.priority = NSLayoutPriorityDefaultLow;
    
    [view addConstraint:_subjectTrailingConstraint];
}

- (void)removeLabel:(id)sender {
    SMLabelWithCloseButton *label = sender;
    
    SM_LOG_INFO(@"removing label %@", label.object);
}

@end
