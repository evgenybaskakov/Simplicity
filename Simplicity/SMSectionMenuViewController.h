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
@property (readonly) NSString *selectedItem;

- (void)addSection:(NSString*)sectionName;
- (void)addItem:(NSString*)itemName section:(NSString*)sectionName target:(id)target action:(SEL)action;
- (void)clearAllItems;
- (void)reloadItems;
- (void)selectItem:(NSInteger)itemIndex;
- (void)unselectItem:(NSInteger)itemIndex;
- (void)cursorDown;
- (void)cursorUp;

@end
