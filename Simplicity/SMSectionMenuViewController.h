//
//  SMSuggestionsMenuViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMSectionMenuViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

@property (readonly) NSUInteger totalHeight;

- (void)addSection:(NSString*)sectionName;
- (void)addItem:(NSString*)itemName object:(id)object section:(NSString*)sectionName target:(id)target action:(SEL)action;
- (NSString*)getSelectedItemWithObject:(id*)object;
- (void)clearAllItems;
- (void)reloadItems;
- (void)selectItem:(NSInteger)itemIndex;
- (void)unselectItem:(NSInteger)itemIndex;
- (BOOL)triggerSelectedItemAction;
- (void)cursorDown;
- (void)cursorUp;

@end
