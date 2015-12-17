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
#import "SMFolderLabel.h"
#import "SMFolderColorController.h"
#import "SMMailboxController.h"
#import "SMPreferencesController.h"
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
    BOOL _hasPendingChanges;
    NSMutableDictionary<NSNumber*, NSColorWell*> *_colorWells;
    NSMutableDictionary<NSNumber*, NSButton*> *_visibleButtons;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _selectedAccount = 0; // TODO: use current account; reset this if account is deleted
    
    [self initAccountList];
    
    _reloadProgressIndicator.hidden = YES;

    _colorWells = [NSMutableDictionary dictionary];
    _visibleButtons = [NSMutableDictionary dictionary];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newLabelCreated) name:@"NewLabelCreated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLabels) name:@"FolderListUpdated" object:nil];
}

- (void)viewDidAppear {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectLabelColorAction:) name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
}

- (void)viewDidDisappear {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];

    [self hideColorPanel];
    [self saveLabels];
}

- (void)showProgress {
    [_reloadProgressIndicator startAnimation:self];

    _reloadProgressIndicator.hidden = NO;
}

- (void)hideProgress {
    [_reloadProgressIndicator stopAnimation:self];
    
    _reloadProgressIndicator.hidden = YES;
}

- (void)newLabelCreated {
    [self showProgress];
}

- (void)updateLabels {
    [self hideProgress];

    [_colorWells removeAllObjects];
    [_visibleButtons removeAllObjects];
    [_labelTable reloadData];
}

- (void)saveLabels {
    if(!_hasPendingChanges) {
        return;
    }

    // Save label colors.
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMFolderColorController *folderColorController = [[appDelegate appController] folderColorController];
    SMMailbox *mailbox = [[appDelegate model] mailbox];
 
    for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
        NSColorWell *colorWell = [_colorWells objectForKey:[NSNumber numberWithInteger:i]];
        
        if(colorWell != nil) {
            SMFolder *folder = mailbox.folders[i];
            [folderColorController setFolderColor:folder.fullName color:colorWell.color];
        }
    }

    // Save label visibility states.
    NSUInteger accountIdx = _selectedAccount;
    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:[[appDelegate preferencesController] labels:accountIdx]];
    for(NSUInteger i = 0, n = mailbox.folders.count; i < n; i++) {
        NSButton *checkbox = [_visibleButtons objectForKey:[NSNumber numberWithInteger:i]];
        
        if(checkbox != nil) {
            SMFolder *folder = mailbox.folders[i];
            SMFolderLabel *label = [updatedLabels objectForKey:folder.fullName];

            label.visible = (checkbox.state == NSOnState? YES : NO);
        }
    }
    
    [[appDelegate preferencesController] setLabels:_selectedAccount labels:updatedLabels];

    _hasPendingChanges = FALSE;
}

- (void)hideColorPanel {
    [[NSColorPanel sharedColorPanel] orderOut:nil];
}

- (void)selectLabelColorAction:(NSNotification*)notification {
    _hasPendingChanges = TRUE;
}

- (void)reloadAccountLabels {
    NSString *selectedAccountName = _accountList.titleOfSelectedItem;
    
    [self initAccountList];
    
    _selectedAccount = [[_accountList itemTitles] indexOfObjectIdenticalTo:selectedAccountName];
    if(_selectedAccount == NSNotFound) {
        SM_LOG_INFO(@"Account %@ disappeared, using default signature list position", selectedAccountName);
        
        _selectedAccount = 0;
    }
    
    [_accountList selectItemAtIndex:_selectedAccount];
    
    [self updateLabels];
}

- (void)initAccountList {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    [_accountList removeAllItems];
    
    for(NSUInteger i = 0, n = [[appDelegate preferencesController] accountsCount]; i < n; i++) {
        [_accountList addItemWithTitle:[[appDelegate preferencesController] accountName:i]];
    }
    
    [_accountList selectItemAtIndex:_selectedAccount];
}

#pragma mark IB actions

- (IBAction)accountListAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    _selectedAccount = [_accountList indexOfSelectedItem];
    
    [self updateLabels];
}

- (IBAction)addLabelAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    NSString *nestingLabel = nil;
    if(_labelTable.selectedRow >= 0) {
        SMMailbox *mailbox = [[appDelegate model] mailbox];
        SMFolder *folder = mailbox.folders[_labelTable.selectedRow];
        
        nestingLabel = folder.fullName;
    }
    
    [appController showNewLabelSheet:nestingLabel];
}

- (IBAction)removeLabelAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    SM_LOG_INFO(@"TODO");
}

- (IBAction)reloadLabelsAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];
    [self showProgress];

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailboxController *mailboxController = [[appDelegate model] mailboxController];

    [mailboxController scheduleFolderListUpdate:YES];
}

- (IBAction)labelVisibleCheckAction:(id)sender {
    _hasPendingChanges = YES;
}

#pragma mark Table implementation

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailbox *mailbox = [[appDelegate model] mailbox]; // TODO: use selected account index here
    
    return mailbox.folders.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    SMMailbox *mailbox = [[appDelegate model] mailbox]; // TODO: use selected account index here
    SMFolder *folder = mailbox.folders[row];
    
    NSNumber *rowNumber = [NSNumber numberWithInteger:row];
    
    if([tableColumn.identifier isEqualToString:@"Color"]) {
        NSColorWell *colorWell = [_colorWells objectForKey:rowNumber];
        if(colorWell == nil) {
            colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];

            [_colorWells setObject:colorWell forKey:rowNumber];
        }
        
        // TODO: use selected account index here too
        colorWell.color = [[appController folderColorController] colorForFolder:folder.fullName];

        return colorWell;
    }
    else if([tableColumn.identifier isEqualToString:@"Label"]) {
        NSTableCellView *view = [tableView makeViewWithIdentifier:@"LabelTableCell" owner:self];
        view.textField.stringValue = folder.fullName;
        
        return view;
    }
    else if([tableColumn.identifier isEqualToString:@"Visible"]) {
        NSButton *checkbox = [_visibleButtons objectForKey:rowNumber];
        if(checkbox == nil) {
            checkbox = [tableView makeViewWithIdentifier:@"VisibleCheckBox" owner:self];
            [_visibleButtons setObject:checkbox forKey:rowNumber];
        }
        
        SMFolderLabel *label = [[[appDelegate preferencesController] labels:_selectedAccount] objectForKey:folder.fullName];
        checkbox.state = (label != nil? (label.visible? NSOnState : NSOffState) : NSOnState);
        
        return checkbox;
    }
    else {
        return nil;
    }
}

@end