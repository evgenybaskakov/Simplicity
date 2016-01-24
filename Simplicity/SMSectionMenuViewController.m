//
//  SMSuggestionsMenuViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMBoxView.h"
#import "SMSectionMenuSeparatorView.h"
#import "SMSectionMenuItemView.h"
#import "SMSectionMenuViewController.h"

@interface ItemInfo : NSOrderedSet
@property NSString *label;
@property Boolean separator;
@property id target;
@property SEL action;
- (id)initWithLabel:(NSString*)label separator:(Boolean)separator target:(id)target action:(SEL)action;
@end

@implementation ItemInfo

- (id)initWithLabel:(NSString*)label separator:(Boolean)separator target:(id)target action:(SEL)action {
    self = [super init];
    
    if(self) {
        _label = label;
        _separator = separator;
        _target = target;
        _action = action;
    }
    
    return self;
}

@end

@interface SMSectionMenuViewController ()

@end

@implementation SMSectionMenuViewController {
    NSMutableArray<NSString*> *_sections;
    NSMutableArray<NSMutableArray<ItemInfo*>*> *_sectionItems;
    NSMutableArray<ItemInfo*> *_itemsFlat;
    NSInteger _selectedItemIndex;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _sections = [NSMutableArray array];
    _sectionItems = [NSMutableArray array];
    _itemsFlat = [NSMutableArray array];
}

- (void)addSection:(NSString*)sectionName {
    if([_sections containsObject:sectionName]) {
        return;
    }
    
    [_sections addObject:sectionName];
    [_sectionItems addObject:[NSMutableArray array]];
    [_sectionItems.lastObject addObject:[[ItemInfo alloc] initWithLabel:sectionName separator:YES target:nil action:nil]];
}

- (void)addItem:(NSString*)itemName section:(NSString*)sectionName target:(id)target action:(SEL)action {
    NSUInteger idx = [_sections indexOfObject:sectionName];
    NSAssert(idx != NSNotFound, @"section %@ not found", sectionName);
    
    [_sectionItems[idx] addObject:[[ItemInfo alloc] initWithLabel:itemName separator:NO target:target action:action]];
}

- (void)clearAllItems {
    [_sections removeAllObjects];
    [_sectionItems removeAllObjects];
    [_itemsFlat removeAllObjects];
}

- (void)reloadItems {
    [_itemsFlat removeAllObjects];

    for(NSMutableArray<ItemInfo*> *section in _sectionItems) {
        for(ItemInfo *item in section) {
            [_itemsFlat addObject:item];
        }
    }
    
    [_itemsTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _itemsFlat.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    if(row < 0) {
        return 0;
    }
    
    ItemInfo *item = _itemsFlat[row];
    
    if(item.separator) {
        SMSectionMenuSeparatorView *separatorView = [tableView makeViewWithIdentifier:@"SectionMenuSeparator" owner:self];
        
        SMBoxView *separatorBox = (SMBoxView*)separatorView.separatorLine;
        
        separatorBox.drawTop = YES;
        separatorBox.drawBottom = YES;
        separatorBox.fillColor = [NSColor colorWithWhite:0.9 alpha:1.0];
        separatorBox.boxColor = [NSColor colorWithWhite:0.9 alpha:1.0];
        
        separatorView.textField.stringValue = item.label;
        
        if(row == 0) {
            separatorView.separatorLine.hidden = YES;
        }
        else {
            separatorView.separatorLine.hidden = NO;
        }
    
        return separatorView;
    }
    else {
        SMSectionMenuItemView *itemView = [tableView makeViewWithIdentifier:@"SectionMenuItem" owner:self];
        
        itemView.parentMenuViewController = self;
        itemView.textField.stringValue = item.label;
        itemView.textField.tag = row;
        
        return itemView;
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if(row < 0) {
        return 0;
    }
    
    ItemInfo *item = _itemsFlat[row];

    return !item.separator;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if(row < 0) {
        return 0;
    }
    
    ItemInfo *item = _itemsFlat[row];
    
    return item.separator? 22 : 17;
}

- (void)selectItem:(NSInteger)itemIndex {
    [_itemsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    
    _selectedItemIndex = itemIndex;
}

- (void)unselectItem:(NSInteger)itemIndex {
    if(itemIndex == _selectedItemIndex) {
        [_itemsTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];

        _selectedItemIndex = -1;
    }
}

- (IBAction)cellAction:(id)sender {
    if(_selectedItemIndex != -1) {
        NSLog(@"click action: row %ld", _selectedItemIndex);
    }
}

@end
