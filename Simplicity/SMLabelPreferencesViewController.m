//
//  SMLabelPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMFolderColorController.h"
#import "SMLabelPreferencesViewController.h"

@interface SMLabelPreferencesViewController ()

@property (weak) IBOutlet NSPopUpButton *accountList;
@property (weak) IBOutlet NSTableView *labelTable;
@property (weak) IBOutlet NSButton *addLabelButton;
@property (weak) IBOutlet NSButton *removeLabelButton;
@property (weak) IBOutlet NSButton *reloadLabelsButton;
@property (weak) IBOutlet NSProgressIndicator *reloadProgressIndicator;

@end

@implementation SMLabelPreferencesViewController {
    NSUInteger _selectedAccount;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do view setup here.

    _selectedAccount = 0; // TODO: use current account; reset this if account is deleted

    _reloadProgressIndicator.hidden = YES;
}

- (void)viewDidAppear {
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectLabelColorAction:) name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
}

- (void)viewDidDisappear {
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
}

- (IBAction)accountListAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (IBAction)addLabelAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (IBAction)removeLabelAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (IBAction)reloadLabelsAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [[appDelegate model] mailbox];
    
    return mailbox.folders.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    SMMailbox *mailbox = [[appDelegate model] mailbox];
    SMFolder *folder = mailbox.folders[row];

    if([tableColumn.identifier isEqualToString:@"Color"]) {
        NSColorWell *colorWell = [tableView makeViewWithIdentifier:@"LabelColorWell" owner:self];
        NSColor *color = [[appController folderColorController] colorForFolder:folder.fullName];
        
        colorWell.color = color;
        
        return colorWell;
    }
    else if([tableColumn.identifier isEqualToString:@"Label"]) {
        NSTableCellView *view = [tableView makeViewWithIdentifier:@"LabelTableCell" owner:self];
        view.textField.stringValue = folder.fullName;
        
        return view;
    }
    else if([tableColumn.identifier isEqualToString:@"Visible"]) {
        return [tableView makeViewWithIdentifier:@"VisibleCheckBox" owner:self];
    }
    else {
        return nil;
    }
}

- (IBAction)selectLabelColorAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (IBAction)labelVisibleCheckAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

@end
