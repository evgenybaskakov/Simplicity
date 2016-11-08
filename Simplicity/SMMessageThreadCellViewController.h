//
//  SMMessageThreadCellViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/24/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMBoxView;
@class SMMessageBodyViewController;
@class SMMessageThreadViewController;

@interface SMMessageThreadCellViewController : NSViewController

@property (readonly) SMBoxView *boxView;

@property (nonatomic) BOOL collapsed;
@property (nonatomic) BOOL shouldDrawBottomLineWhenCollapsed;
@property (nonatomic) BOOL shouldDrawBottomLineWhenUncollapsed;
@property (nonatomic) NSUInteger cellIndex;

@property (readonly, nonatomic) NSUInteger cellHeight;
@property (readonly, nonatomic) NSUInteger cellHeaderHeight;
@property (readonly, nonatomic) NSUInteger stringOccurrencesCount;
@property (readonly, nonatomic) BOOL mainFrameLoaded;

@property (readonly, nonatomic) __weak SMMessageThreadViewController *messageThreadViewController;

+ (NSUInteger)collapsedCellHeight;

- (id)init:(SMMessageThreadViewController*)messageThreadViewController collapsed:(BOOL)collapsed;
- (void)setMessage:(SMMessage*)message;
- (void)updateMessage;
- (BOOL)loadMessageBody;
- (void)enableCollapse:(BOOL)enable;
- (void)adjustCellHeightToFitContentResizeable:(BOOL)heightResizeable;

#pragma mark Saving attachments

- (void)saveAttachments;
- (void)saveAttachmentsToDownloads;

#pragma mark Finding contents

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(BOOL)matchCase;
- (NSInteger)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;

@end
