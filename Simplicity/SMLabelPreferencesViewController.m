//
//  SMLabelPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
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
    return 2;
}

- (IBAction)selectLabelColorAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

- (IBAction)labelVisibleCheckAction:(id)sender {
    SM_LOG_INFO(@"TODO");
}

@end
