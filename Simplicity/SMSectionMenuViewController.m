//
//  SMSuggestionsMenuViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMBoxView.h"
#import "SMSectionMenuSeparatorView.h"
#import "SMSectionMenuItemView.h"
#import "SMSectionMenuViewController.h"

typedef NS_ENUM(NSUInteger, ItemKind) {
    ItemKind_Separator,
    ItemKind_TopLevel,
    ItemKind_BottomLevel,
};

@interface ItemInfo : NSOrderedSet
@property NSString *label;
@property NSString *value;
@property id object;
@property ItemKind kind;
@property id target;
@property SEL action;
- (id)initWithLabel:(NSString*)label value:(NSString*)value object:(NSObject*)object kind:(ItemKind)kind target:(id)target action:(SEL)action;
@end

@implementation ItemInfo

- (id)initWithLabel:(NSString*)label value:(NSString*)value object:(id)object kind:(ItemKind)kind target:(id)target action:(SEL)action {
    self = [super init];
    
    if(self) {
        _label = label;
        _value = value;
        _object = object;
        _kind = kind;
        _target = target;
        _action = action;
    }
    
    return self;
}

@end

@interface SMSectionMenuViewController ()
@property (weak) IBOutlet NSTableView *itemsTable;
@end

@implementation SMSectionMenuViewController {
    NSMutableArray<NSString*> *_sections;
    NSMutableArray<NSMutableArray<ItemInfo*>*> *_sectionItems;
    NSArray<ItemInfo*> *_itemsFlat;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _sections = [NSMutableArray array];
    _sectionItems = [NSMutableArray array];
    _itemsFlat = [NSMutableArray array];
    
    _itemsTable.backgroundColor = [NSColor clearColor];
    
    NSVisualEffectView *view = (NSVisualEffectView*)self.view;
    
    view.state = NSVisualEffectStateActive;
    view.material = NSVisualEffectMaterialLight;
    view.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    
    CGFloat cornerRadius = 5;
    
    NSRect bounds = self.view.bounds;
    view.maskImage =
    [NSImage imageWithSize:bounds.size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:cornerRadius yRadius:cornerRadius];
        [path fill];
        return YES;
    }];
    
    view.maskImage.capInsets = NSEdgeInsetsMake(cornerRadius, cornerRadius, cornerRadius, cornerRadius);
}

- (void)addSection:(NSString*)sectionName {
    if([_sections containsObject:sectionName]) {
        return;
    }
    
    [_sections addObject:sectionName];
    [_sectionItems addObject:[NSMutableArray array]];
    [_sectionItems.lastObject addObject:[[ItemInfo alloc] initWithLabel:sectionName value:nil object:nil kind:ItemKind_Separator target:nil action:nil]];
}

- (void)addTopLevelItem:(NSString*)topLevelItemTitle topLevelItemValue:(NSString*)topLevelItemValue object:(id)object section:(NSString*)sectionName target:(id)target action:(SEL)action {
    NSUInteger idx = [_sections indexOfObject:sectionName];
    NSAssert(idx != NSNotFound, @"section %@ not found", sectionName);
    
    [_sectionItems[idx] addObject:[[ItemInfo alloc] initWithLabel:topLevelItemTitle value:topLevelItemValue object:object kind:ItemKind_TopLevel target:target action:action]];
}

- (void)addItem:(NSString*)itemName object:(id)object section:(NSString*)sectionName target:(id)target action:(SEL)action {
    NSUInteger idx = [_sections indexOfObject:sectionName];
    NSAssert(idx != NSNotFound, @"section %@ not found", sectionName);
    
    [_sectionItems[idx] addObject:[[ItemInfo alloc] initWithLabel:itemName value:itemName object:object kind:ItemKind_BottomLevel target:target action:action]];
}

- (NSString*)getSelectedItemWithObject:(id*)object {
    NSInteger selectedRow = _itemsTable.selectedRow;
    
    if(selectedRow >= 0 && selectedRow < _itemsFlat.count) {
        *object = _itemsFlat[selectedRow].object;
        return _itemsFlat[selectedRow].value;
    }
    else {
        return nil;
    }
}

- (void)clearItemsWithObject:(id)object {
    for(NSUInteger s = 0; s < _sectionItems.count; s++) {
        NSMutableArray<ItemInfo*> *section = _sectionItems[s];
        NSMutableArray<ItemInfo*> *newSection = [NSMutableArray array];
        
        for(NSUInteger i = 0, j = 0; i < section.count; i++) {
            if(section[i].object != object) {
                newSection[j++] = section[i];
            }
        }
        
        _sectionItems[s] = newSection;
    }
}

- (void)reloadItems {
    NSMutableArray *flatItems = [NSMutableArray array];
    
    for(NSArray<ItemInfo*> *section in _sectionItems) {
        // Skip sections containing only header
        if(section.count > 1) {
            NSArray *sortedItems = [section sortedArrayUsingComparator:^NSComparisonResult(ItemInfo *item1, ItemInfo *item2) {
                if(item1.kind == ItemKind_Separator) {
                    NSAssert(item2.kind != ItemKind_Separator, @"there must not be two separators in the same section");
                    return NSOrderedAscending;
                }
                else if(item2.kind == ItemKind_Separator) {
                    NSAssert(item1.kind != ItemKind_Separator, @"there must not be two separators in the same section");
                    return NSOrderedDescending;
                }
                else if(item1.kind == ItemKind_TopLevel) {
                    if(item2.kind == ItemKind_TopLevel) {
                        return [item1.label compare:item2.label];
                    }
                    else {
                        return NSOrderedAscending;
                    }
                }
                else if(item2.kind == ItemKind_TopLevel) {
                    return NSOrderedDescending;
                }
                else {
                    return [item1.label compare:item2.label];
                }
            }];
            
            for(ItemInfo *item in sortedItems) {
                if(flatItems.count == 0 || ![[flatItems.lastObject label] isEqualToString:item.label]) {
                    [flatItems addObject:item];
                }
            }
        }
    }
    
    _itemsFlat = flatItems;
    
    [_itemsTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _itemsFlat.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    if(row < 0 || row >= _itemsFlat.count) {
        SM_LOG_WARNING(@"row %ld is out of bounds (item count %lu)", row, _itemsFlat.count);
        return nil;
    }
    
    ItemInfo *item = _itemsFlat[row];
    
    if(item.kind == ItemKind_Separator) {
        SMSectionMenuSeparatorView *separatorView = [tableView makeViewWithIdentifier:@"SectionMenuSeparator" owner:self];
        
        SMBoxView *separatorBox = separatorView.separatorLine;
        
        separatorBox.drawTop = YES;
        separatorBox.drawBottom = YES;
        separatorBox.fillColor = [NSColor colorWithWhite:0.75 alpha:1.0];
        separatorBox.boxColor = [NSColor colorWithWhite:0.75 alpha:1.0];
        
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
        
        [itemView updateTrackingAreas];
        
        return itemView;
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if(row < 0 || row >= _itemsFlat.count) {
        SM_LOG_WARNING(@"row %ld is out of bounds (item count %lu)", row, _itemsFlat.count);
        return FALSE;
    }
    
    ItemInfo *item = _itemsFlat[row];

    return item.kind != ItemKind_Separator;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if(row < 0) {
        return 0;
    }
    
    ItemInfo *item = _itemsFlat[row];
    
    return item.kind == ItemKind_Separator? 22 : 17;
}

- (void)selectItem:(NSInteger)itemIndex {
    [_itemsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
}

- (void)unselectItem:(NSInteger)itemIndex {
    if(itemIndex == _itemsTable.selectedRow) {
        [_itemsTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    }
}

- (BOOL)triggerSelectedItemAction {
    NSInteger selectedRow = _itemsTable.selectedRow;
    
    if(selectedRow >= 0 && selectedRow < _itemsFlat.count) {
        [self cellAction:self];
        
        return TRUE;
    }
    else {
        return FALSE;
    }
}

- (IBAction)cellAction:(id)sender {
    NSInteger selectedRow = _itemsTable.selectedRow;
    
    if(selectedRow >= 0 && selectedRow < _itemsFlat.count) {
        ItemInfo *item = _itemsFlat[selectedRow];
        
        if(item.target != nil) {
            [item.target performSelector:item.action withObject:self afterDelay:0];
        }
    }
    else {
        SM_LOG_ERROR(@"click action is beyond table bounds (row %ld item count %lu)", selectedRow, _itemsFlat.count);
    }
}

- (NSUInteger)totalHeight {
    NSAssert(_itemsTable.numberOfRows > 0, @"no rows in the search menu");
    
    NSInteger viewHeight = 0;
    
    for(NSUInteger i = 0, n = [_itemsTable numberOfRows]; i < n; i++) {
        viewHeight += [self tableView:_itemsTable heightOfRow:i];
        
        if(i+1 < n) {
            viewHeight += _itemsTable.intercellSpacing.height;
        }
    }
    
    return viewHeight + 3;
}

- (void)cursorDown {
    const int codeArrowDown = 125;
    
    NSEvent* keyEvent = [NSEvent keyEventWithType:NSKeyDown
                                         location:NSMakePoint(0, 0)
                                    modifierFlags:NSCommandKeyMask
                                        timestamp:[NSDate timeIntervalSinceReferenceDate]
                                     windowNumber:[[[NSApplication sharedApplication] mainWindow] windowNumber]
                                          context:[NSGraphicsContext currentContext]
                                       characters:@""
                      charactersIgnoringModifiers:@""
                                        isARepeat:NO
                                          keyCode:codeArrowDown];
    
    [_itemsTable keyDown:keyEvent];
}

- (void)cursorUp {
    const int codeArrowUp = 126;
    
    NSEvent* keyEvent = [NSEvent keyEventWithType:NSKeyDown
                                         location:NSMakePoint(0, 0)
                                    modifierFlags:NSCommandKeyMask
                                        timestamp:[NSDate timeIntervalSinceReferenceDate]
                                     windowNumber:[[[NSApplication sharedApplication] mainWindow] windowNumber]
                                          context:[NSGraphicsContext currentContext]
                                       characters:@""
                      charactersIgnoringModifiers:@""
                                        isARepeat:NO
                                          keyCode:codeArrowUp];

    [_itemsTable keyDown:keyEvent];
}

@end
