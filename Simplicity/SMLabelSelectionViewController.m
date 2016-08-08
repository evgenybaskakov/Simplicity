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
#import "SMLabelSelectionViewController.h"

@interface SMLabelSelectionViewController ()

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
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    view.circle.color = [[appDelegate.currentAccount folderColorController] colorForFolder:folder.fullName];
    view.textField.stringValue = folder.displayName;
    
    return view;
}

@end
