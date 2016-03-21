//
//  SMMailboxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/21/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMFolderCellView.h"
#import "SMUserAccount.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMSearchResultsListController.h"
#import "SMNotificationsController.h"
#import "SMColorCircle.h"
#import "SMMailboxController.h"
#import "SMMailboxViewController.h"
#import "SMMailboxMainFolderView.h"
#import "SMMailboxLabelView.h"
#import "SMFolderColorController.h"
#import "SMPreferencesController.h"
#import "SMFolderLabel.h"
#import "SMMailboxRowView.h"

@implementation SMMailboxViewController {
    NSInteger _rowWithMenu;
    NSString *_labelToRename;
    Boolean _favoriteFolderSelected;
    NSBox *_hightlightBox;
    Boolean _doHightlightRow;
    NSMutableArray *_favoriteFolders;
    NSMutableArray *_visibleFolders;
    SMFolder *_prevFolder;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _rowWithMenu = -1;
        _favoriteFolders = [NSMutableArray array];
        _visibleFolders = [NSMutableArray array];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [_folderListView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [_folderListView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsUpdated:) name:@"MessageFlagsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messagesUpdated:) name:@"MessagesUpdated" object:nil];
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
    NSString *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder hasUpdates:nil account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        [self updateFolders:localFolder];
    }
}

- (void)messageFlagsUpdated:(NSNotification *)notification {
    NSString *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageFlagsUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        [self updateFolders:localFolder];
    }
}

- (void)messagesUpdated:(NSNotification *)notification {
    NSString *localFolder;
    SMUserAccount *account;
    
    [SMNotificationsController getMessagesUpdatedParams:notification localFolder:&localFolder account:&account];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(account == appDelegate.currentAccount) {
        [self updateFolders:localFolder];
    }
}

- (void)updateFolders:(NSString*)localFolder {
    (void)localFolder;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [[appDelegate.currentAccount mailbox] selectedFolder];
    
    if(selectedFolder != nil) {
        NSInteger selectedRow = -1;

        selectedRow = [self getFolderRow:selectedFolder];

        [ _folderListView reloadData ];
        
        if(selectedRow >= 0) {
            [ _folderListView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO ];
        } else {
            [ _folderListView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO ];
        }
    }
    else {
        [ _folderListView reloadData ];
    }
}

- (void)updateFolderListView {
    NSInteger selectedRow = -1;

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    [_favoriteFolders removeAllObjects];
    [_visibleFolders removeAllObjects];
    
    NSDictionary<NSString*, SMFolderLabel*> *labels = [[appDelegate preferencesController] labels:appDelegate.currentAccountIdx];
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    
    for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
        SMFolder *folder = mailbox.folders[i];
        SMFolderLabel *label = [labels objectForKey:folder.fullName];
        
        if((label != nil && label.visible) || label == nil) {
            [_visibleFolders addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
        
        if((label != nil && label.favorite) || label == nil) {
            [_favoriteFolders addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }

    SMFolder *selectedFolder = [[appDelegate.currentAccount mailbox] selectedFolder];
    if(selectedFolder != nil) {
        selectedRow = [self getFolderRow:selectedFolder];
    }
    
    [ _folderListView reloadData ];

    if(selectedRow >= 0) {
        [ _folderListView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO ];
    } else {
        [ _folderListView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO ];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [_folderListView selectedRow];
    if(selectedRow < 0 || selectedRow >= [self totalFolderRowsCount])
        return;

    SMFolder *folder = [self selectedFolder:selectedRow favoriteFolderSelected:&_favoriteFolderSelected];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [[appDelegate.currentAccount mailbox] selectedFolder];
    
    if(folder == nil || [folder.fullName isEqualToString:selectedFolder.fullName])
        return;
    
    SM_LOG_DEBUG(@"selected row %lu, folder full name '%@'", selectedRow, folder.fullName);

    [self doChangeFolder:folder];
}

- (void)changeFolder:(NSString*)folderName {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *folder = [[appDelegate.currentAccount mailbox] getFolderByName:folderName];
    
    [self doChangeFolder:folder];
}

- (void)doChangeFolder:(SMFolder*)folder {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [[appDelegate.currentAccount searchResultsListController] stopLatestSearch];
    
    [[[appDelegate appController] messageListViewController] stopProgressIndicators];
    [[appDelegate.currentAccount messageListController] changeFolder:(folder != nil? folder.fullName : nil)];
    
    SMFolder *selectedFolder = [[appDelegate.currentAccount mailbox] selectedFolder];
    
    _prevFolder = selectedFolder;

    [appDelegate.currentAccount mailbox].selectedFolder = folder;
    
    [self updateFolderListView];
}

- (void)changeToPrevFolder {
    if(_prevFolder != nil) {
        [self changeFolder:_prevFolder.fullName];
        _prevFolder = nil;
    }
}

- (void)clearSelection {
    [_folderListView deselectAll:self];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *selectedFolder = [[appDelegate.currentAccount mailbox] selectedFolder];
    
    if(selectedFolder != nil) {
        _prevFolder = selectedFolder;

        [appDelegate.currentAccount mailbox].selectedFolder = nil;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self totalFolderRowsCount];
}

- (NSInteger)mainFoldersGroupOffset {
    return 0;
}

- (NSInteger)favoriteFoldersGroupOffset {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];

    return 1 + mailbox.mainFolders.count;
}

- (NSInteger)allFoldersGroupOffset {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    
    return 1 + mailbox.mainFolders.count + 1 + _favoriteFolders.count;
}

- (NSInteger)totalFolderRowsCount {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if(appDelegate.accounts.count == 0) {
        return 0;
    }

    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    
    return 1 + mailbox.mainFolders.count + 1 + _favoriteFolders.count + 1 + _visibleFolders.count;
}

- (SMFolder*)selectedFolder:(NSInteger)row {
    return [self selectedFolder:row favoriteFolderSelected:nil];
}

- (SMFolder*)selectedFolder:(NSInteger)row favoriteFolderSelected:(Boolean*)favoriteFolderSelected {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];
    
    if(row > mainFoldersGroupOffset && row < favoriteFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = NO;
        }
        
        return mailbox.mainFolders[row - mainFoldersGroupOffset - 1];
    } else if(row > favoriteFoldersGroupOffset && row < allFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = YES;
        }
        
        NSUInteger idx = [_favoriteFolders[row - favoriteFoldersGroupOffset - 1] unsignedIntegerValue];
        return mailbox.folders[idx];
    } else if(row > allFoldersGroupOffset) {
        if(favoriteFolderSelected != nil) {
            *favoriteFolderSelected = NO;
        }
        
        NSUInteger idx = [_visibleFolders[row - allFoldersGroupOffset - 1] unsignedIntegerValue];
        return mailbox.folders[idx];
    } else {
        return nil;
    }
}

- (NSInteger)getFolderRow:(SMFolder*)folder {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [appDelegate.currentAccount mailbox];
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];
    
    if(_favoriteFolderSelected) {
        for(NSUInteger i = 0; i < _favoriteFolders.count; i++) {
            NSUInteger idx = [_favoriteFolders[i] unsignedIntegerValue];

            if(mailbox.folders[idx] == folder) {
                return i + favoriteFoldersGroupOffset + 1;
            }
        }
    } else {
        for(NSUInteger i = 0; i < mailbox.mainFolders.count; i++) {
            if(mailbox.mainFolders[i] == folder)
                return i + mainFoldersGroupOffset + 1;
        }

        for(NSUInteger i = 0; i < _visibleFolders.count; i++) {
            NSUInteger idx = [_visibleFolders[i] unsignedIntegerValue];
            
            if(mailbox.folders[idx] == folder) {
                return i + allFoldersGroupOffset + 1;
            }
        }
    }
    
    return -1;
}

- (NSImage*)mainFolderImage:(SMFolder*)folder {
    switch(folder.kind) {
        case SMFolderKindInbox:
            return [NSImage imageNamed:@"inbox-white.png"];
        case SMFolderKindImportant:
            return [NSImage imageNamed:@"important-white.png"];
        case SMFolderKindSent:
            return [NSImage imageNamed:@"sent-white.png"];
        case SMFolderKindSpam:
            return [NSImage imageNamed:@"spam-white.png"];
        case SMFolderKindOutbox:
            return [NSImage imageNamed:@"outbox-white.png"];
        case SMFolderKindStarred:
            return [NSImage imageNamed:@"star-white.png"];
        case SMFolderKindDrafts:
            return [NSImage imageNamed:@"drafts-white.png"];
        case SMFolderKindTrash:
            return [NSImage imageNamed:@"trash-white.png"];
        default:
            return nil;
    }
}

typedef enum {
    kMainFoldersGroupHeader,
    kFavoriteFoldersGroupHeader,
    kAllFoldersGroupHeader,
    kMainFoldersGroupItem,
    kFavoriteFoldersGroupItem,
    kAllFoldersGroupItem
} FolderListItemKind;

- (FolderListItemKind)getRowKind:(NSInteger)row {
    NSInteger totalRowCount = [self totalFolderRowsCount];
    NSAssert(row >= 0 && row < totalRowCount, @"row %ld is beyond folders array size %lu", row, totalRowCount);
    
    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];

    if(row == mainFoldersGroupOffset) {
        return kMainFoldersGroupHeader;
    } else if(row == favoriteFoldersGroupOffset) {
        return kFavoriteFoldersGroupHeader;
    } else if(row == allFoldersGroupOffset) {
        return kAllFoldersGroupHeader;
    } else if(row < favoriteFoldersGroupOffset) {
        return kMainFoldersGroupItem;
    } else if(row < allFoldersGroupOffset) {
        return kFavoriteFoldersGroupItem;
    } else {
        return kAllFoldersGroupItem;
    }
}

- (NSIndexSet *)tableView:(NSTableView*)tableView selectionIndexesForProposedSelection:(NSIndexSet*)proposedSelectionIndexes {
    NSMutableIndexSet *newSelection = [[NSMutableIndexSet alloc] initWithIndexSet:proposedSelectionIndexes];

    // Scan the proposed selection and exclude folder section headers.
    for(NSUInteger row = proposedSelectionIndexes.firstIndex; row != NSNotFound; row = [proposedSelectionIndexes indexGreaterThanIndex:row]) {
        FolderListItemKind kind = [self getRowKind:row];
        
        if(kind == kMainFoldersGroupHeader || kind == kFavoriteFoldersGroupHeader || kind == kAllFoldersGroupHeader) {
            [newSelection removeIndex:row];
        }
    }
    
    return newSelection.count > 0? newSelection : tableView.selectedRowIndexes;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSInteger totalRowCount = [self totalFolderRowsCount];
    NSAssert(row >= 0 && row < totalRowCount, @"row %ld is beyond folders array size %lu", row, totalRowCount);

    const NSInteger mainFoldersGroupOffset = [self mainFoldersGroupOffset];
    const NSInteger favoriteFoldersGroupOffset = [self favoriteFoldersGroupOffset];
    const NSInteger allFoldersGroupOffset = [self allFoldersGroupOffset];

    NSTableCellView *result = nil;

    FolderListItemKind itemKind = [self getRowKind:row];
    switch(itemKind) {
        case kMainFoldersGroupItem: {
            result = [tableView makeViewWithIdentifier:@"MainFolderCellView" owner:self];
            NSAssert([result isKindOfClass:[SMMailboxMainFolderView class]], @"bad result class");
            
            SMFolder *folder = [self selectedFolder:row];
            NSAssert(folder != nil, @"bad selected folder");
            
            [result.textField setStringValue:folder.displayName];
            [result.imageView setImage:[self mainFolderImage:folder]];

            [self displayUnseenCount:[(SMMailboxMainFolderView*)result unreadCount] folderName:folder];
            
            break;
        }
            
        case kFavoriteFoldersGroupItem:
        case kAllFoldersGroupItem: {
            result = [tableView makeViewWithIdentifier:@"FolderCellView" owner:self];
            NSAssert([result isKindOfClass:[SMMailboxLabelView class]], @"bad result class");
            
            SMFolder *folder = [self selectedFolder:row];
            NSAssert(folder != nil, @"bad selected folder");
            
            [result.textField setStringValue:folder.displayName];

            [self displayUnseenCount:[(SMMailboxLabelView*)result unreadCount] folderName:folder];
            
            NSAssert([result.imageView isKindOfClass:[SMColorCircle class]], @"bad type of folder cell image");;
            
            SMColorCircle *colorMark = (SMColorCircle *)result.imageView;
            
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            SMAppController *appController = [appDelegate appController];
            
            colorMark.color = [[appController folderColorController] colorForFolder:folder.fullName];

            if(row == _rowWithMenu) {
                if(_doHightlightRow) {
                    if(_hightlightBox == nil) {
                        _hightlightBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
                        
                        _hightlightBox.translatesAutoresizingMaskIntoConstraints = NO;
                        [_hightlightBox setBoxType:NSBoxCustom];
                        [_hightlightBox setBorderColor:[NSColor lightGrayColor]];
                        [_hightlightBox setBorderWidth:1];
                        [_hightlightBox setBorderType:NSBezelBorder];
                        [_hightlightBox setCornerRadius:5];
                        [_hightlightBox setTitlePosition:NSNoTitle];
                    }

                    [result addSubview:_hightlightBox];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeTop multiplier:1.0 constant:-1]];
                    
                    [result addConstraint:[NSLayoutConstraint constraintWithItem:result attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_hightlightBox attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
                } else {
                    [_hightlightBox removeFromSuperview];
                }
            }

            break;
        }
            
        default: {
            result = [tableView makeViewWithIdentifier:@"FolderGroupCellView" owner:self];
            
            const NSUInteger fontSize = 12;
            [result.textField setFont:[NSFont boldSystemFontOfSize:fontSize]];
            
            if(row == mainFoldersGroupOffset) {
                [result.textField setStringValue:@"Main Folders"];
            } else if(row == favoriteFoldersGroupOffset) {
                [result.textField setStringValue:@"Favorite Folders"];
            } else if(row == allFoldersGroupOffset) {
                [result.textField setStringValue:@"All Folders"];
            }
        }
    }
    
    NSAssert(result != nil, @"cannot make folder cell view");
    
    return result;
}

- (void)displayUnseenCount:(NSTextField*)textField folderName:(SMFolder*)folder {
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

    NSUInteger unseenCount;
    if(folder.kind == SMFolderKindDrafts || folder.kind == SMFolderKindOutbox) {
        unseenCount = [[appDelegate.currentAccount mailboxController] totalMessagesCount:folder.fullName];
    }
    else {
        unseenCount = [[appDelegate.currentAccount mailboxController] unseenMessagesCount:folder.fullName];
    }
    
    if(unseenCount != 0) {
        textField.stringValue = [NSString stringWithFormat:@"%lu", unseenCount];
        textField.hidden = NO;
    }
    else {
        textField.stringValue = @"0";
        textField.hidden = YES;
    }
}

#pragma mark Messages drag and drop support

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
    // do not permit dragging folders

    return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    // permit drop only at folders, not between them

    if(op == NSTableViewDropOn) {
        SMFolder *targetFolder = [self selectedFolder:row];

        SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
        if(targetFolder != nil && ![targetFolder.fullName isEqualToString:[[[appDelegate.currentAccount mailbox] selectedFolder] fullName]])
            return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)op
{
    SMFolder *targetFolder = [self selectedFolder:row];

    if(targetFolder == nil) {
        SM_LOG_INFO(@"No target folder");
        return NO;
    }
    
    if(targetFolder.kind == SMFolderKindOutbox) {
        SM_LOG_INFO(@"Cannot move messages to the Outbox folder");
        return NO;
    }

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolder *currentFolder = [[appDelegate.currentAccount mailbox] selectedFolder];

    if(currentFolder.kind == SMFolderKindOutbox && targetFolder.kind != SMFolderKindTrash) {
        SM_LOG_INFO(@"Cannot move messages from the Outbox folder to anything but Trash");
        return NO;
    }

    [[[appDelegate appController] messageListViewController] moveSelectedMessageThreadsToFolder:targetFolder.fullName];
    
    SM_LOG_INFO(@"Moving messages from %@ to %@", currentFolder.fullName, targetFolder.fullName);
    return YES;
}

#pragma mark Context menu creation

- (NSMenu*)menuForRow:(NSInteger)row {
    if(row < 0 || row >= _folderListView.numberOfRows)
        return nil;

    _rowWithMenu = row;
    _doHightlightRow = YES;

    [_folderListView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

    NSMenu *menu = nil;

    FolderListItemKind itemKind = [self getRowKind:row];
    switch(itemKind) {
        case kMainFoldersGroupItem: {
            break;
        }
    
        case kFavoriteFoldersGroupItem: {
            menu = [[NSMenu alloc] init];
            
            [menu addItemWithTitle:@"Delete label" action:@selector(deleteLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Remove label from favorites" action:@selector(removeLabelFromFavorites) keyEquivalent:@""];
            
            [menu setDelegate:self];

            break;
        }

        case kAllFoldersGroupItem: {
            menu = [[NSMenu alloc] init];

            [menu addItemWithTitle:@"New label" action:@selector(newLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Delete label" action:@selector(deleteLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Hide label" action:@selector(hideLabel) keyEquivalent:@""];
            [menu addItemWithTitle:@"Make label favorite" action:@selector(makeLabelFavorite) keyEquivalent:@""];
            
            [menu setDelegate:self];

            break;
        }

        default: {
            break;
        }
    }
    
    return menu;
}

- (void)menuDidClose:(NSMenu *)menu {
    SM_LOG_DEBUG(@"???");

    _doHightlightRow = NO;
    
    [_folderListView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:_rowWithMenu] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)newLabel {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    [appController showNewLabelSheet:folder.fullName];
}

- (void)deleteLabel {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete label %@?", folder.fullName]];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if([alert runModal] != NSAlertFirstButtonReturn) {
        SM_LOG_DEBUG(@"Label deletion cancelled");
        return;
    }
    
    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

    [[appDelegate.currentAccount mailboxController] deleteFolder:folder.fullName];
    
    if([[[[appDelegate.currentAccount mailbox] selectedFolder] fullName] isEqualToString:folder.fullName]) {
        SMFolder *inboxFolder = [[appDelegate.currentAccount mailbox] inboxFolder];
        [[[appDelegate appController] mailboxViewController] changeFolder:inboxFolder.fullName];
    }
}

- (void)hideLabel {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);
    
    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.visible = NO;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];
    
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

- (void)makeLabelFavorite {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.favorite = YES;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];
    
    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

- (void)removeLabelFromFavorites {
    NSAssert(_rowWithMenu >= 0 && _rowWithMenu < _folderListView.numberOfRows, @"bad _rowWithMenu %ld", _rowWithMenu);

    SMFolder *folder = [self selectedFolder:_rowWithMenu];
    NSAssert(folder != nil, @"bad selected folder");

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:appDelegate.currentAccountIdx]];
    SMFolderLabel *label = [labels objectForKey:folder.fullName];
    label.favorite = NO;
    [[appDelegate preferencesController] setLabels:appDelegate.currentAccountIdx labels:labels];

    [[[appDelegate appController] mailboxViewController] updateFolderListView];
}

#pragma mark Editing cells (renaming labels)

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    NSTextField *textField = [obj object];
    
    _labelToRename = textField.stringValue;
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if(_labelToRename == nil)
        return;

    NSTextField *textField = [obj object];
    NSString *newLabelName = textField.stringValue;
    
    if([newLabelName isEqualToString:_labelToRename])
        return;

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    
    [[appDelegate.currentAccount mailboxController] renameFolder:_labelToRename newFolderName:newLabelName];
}

#pragma mark Cell selection

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [[SMMailboxRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

@end
