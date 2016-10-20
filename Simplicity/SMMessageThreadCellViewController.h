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

@property (nonatomic) Boolean collapsed;
@property (nonatomic) Boolean shouldDrawBottomLineWhenCollapsed;
@property (nonatomic) Boolean shouldDrawBottomLineWhenUncollapsed;
@property (nonatomic) NSUInteger cellIndex;

@property (readonly, nonatomic) NSUInteger cellHeight;
@property (readonly, nonatomic) NSUInteger cellHeaderHeight;
@property (readonly, nonatomic) NSUInteger stringOccurrencesCount;
@property (readonly, nonatomic) Boolean mainFrameLoaded;

@property (readonly, nonatomic) __weak SMMessageThreadViewController *messageThreadViewController;

+ (NSUInteger)collapsedCellHeight;

- (id)init:(SMMessageThreadViewController*)messageThreadViewController collapsed:(Boolean)collapsed;
- (void)setMessage:(SMMessage*)message;
- (void)updateMessage;
- (Boolean)loadMessageBody;
- (void)enableCollapse:(Boolean)enable;
- (void)adjustCellHeightToFitContentResizeable:(Boolean)heightResizeable;

#pragma mark Saving attachments

- (void)saveAttachments;
- (void)saveAttachmentsToDownloads;

#pragma mark Finding contents

- (void)highlightAllOccurrencesOfString:(NSString*)str matchCase:(Boolean)matchCase;
- (NSInteger)markOccurrenceOfFoundString:(NSUInteger)index;
- (void)removeMarkedOccurrenceOfFoundString;
- (void)removeAllHighlightedOccurrencesOfString;

@end
