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
#import "SMMailboxController.h"
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
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do view setup here.

    _selectedAccount = 0; // TODO: use current account; reset this if account is deleted

    _reloadProgressIndicator.hidden = YES;

    _colorWells = [NSMutableDictionary dictionary];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newLabelCreated) name:@"NewLabelCreated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsUpdated) name:@"FolderListUpdated" object:nil];
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

- (void)labelsUpdated {
    [self hideProgress];

    [_colorWells removeAllObjects];
    [_labelTable reloadData];
}

- (void)saveLabels {
    if(!_hasPendingChanges) {
        return;
    }

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

    _hasPendingChanges = FALSE;
}

- (void)hideColorPanel {
    [[NSColorPanel sharedColorPanel] orderOut:nil];
}

- (void)selectLabelColorAction:(NSNotification*)notification {
    _hasPendingChanges = TRUE;
}

- (IBAction)accountListAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    SM_LOG_INFO(@"TODO");
}

- (IBAction)addLabelAction:(id)sender {
    [self hideColorPanel];
    [self saveLabels];

    SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController showNewLabelSheet:nil];
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
    SM_LOG_INFO(@"TODO");
}

#pragma mark Table implementation

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
        NSColorWell *colorWell = [_colorWells objectForKey:[NSNumber numberWithInteger:row]];
        if(colorWell == nil) {
            colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];

            [_colorWells setObject:colorWell forKey:[NSNumber numberWithInteger:row]];
        }
        
        colorWell.color = [[appController folderColorController] colorForFolder:folder.fullName];

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

@end
