//
//  SMLabelSelectionViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAbstractAccount.h"
#import "SMFolderColorController.h"
#import "SMFolder.h"
#import "SMColorCircle.h"
#import "SMLabelSelectionRow.h"
#import "SMLabelSelectionTableRowView.h"
#import "SMLabelSelectionViewController.h"
#import "SMMessageThreadInfoViewController.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThread.h"

@interface SMLabelSelectionViewController ()
@property (weak) IBOutlet NSTableView *tableView;
@end

@implementation SMLabelSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _folders.count;
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(row < 0 || row >= _folders.count)
        return nil;
    
    SMFolder *folder = _folders[row];

    SMLabelSelectionRow *view = [tableView makeViewWithIdentifier:@"LabelSelectionRow" owner:self];
    NSAssert(view != nil, @"view is nil");
    
    SMUserAccount *account = _messageThreadInfoViewController.messageThreadViewController.currentMessageThread.account;
    view.circle.color = [[account folderColorController] colorForFolder:folder.fullName];
    view.textField.stringValue = folder.displayName;
    
    return view;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [[SMLabelSelectionTableRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

- (void)setFolders:(NSArray<SMFolder *> *)folders {
    _folders = folders;
    [_tableView reloadData];
}

- (IBAction)clickAction:(id)sender {
    NSInteger row = [sender selectedRow];
    
    [_messageThreadInfoViewController addLabel:_folders[row].fullName];
}

- (NSSize)preferredContentSize {
    CGFloat w = 0;
    for(NSUInteger i = 0, n = _tableView.numberOfRows; i < n; i++) {
        NSSize rowSize = [[self tableView:_tableView viewForTableColumn:nil row:i] fittingSize];
        w = MAX(w, rowSize.width);
    }
    
    NSWindow *mainWindow = [[NSApplication sharedApplication] mainWindow];
    CGFloat h = MIN(_tableView.rowHeight * _tableView.numberOfRows + _tableView.intercellSpacing.height * (_tableView.numberOfRows + 1), mainWindow.frame.size.height);
    
    return NSMakeSize(w + 6, h);
}

@end
