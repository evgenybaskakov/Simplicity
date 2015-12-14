//
//  SMLabelPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLabelPreferencesViewController.h"

@interface SMLabelPreferencesViewController ()
@property (weak) IBOutlet NSPopUpButton *accountList;
@property (weak) IBOutlet NSTableView *labelTable;
@property (weak) IBOutlet NSButton *addLabelButton;
@property (weak) IBOutlet NSButton *removeLabelButton;
@property (weak) IBOutlet NSButton *reloadLabelsButton;
@property (weak) IBOutlet NSProgressIndicator *reloadProgressIndicator;
@end

@implementation SMLabelPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do view setup here.

}

- (IBAction)accountListAction:(id)sender {
}

- (IBAction)addLabelAction:(id)sender {
}

- (IBAction)removeLabelAction:(id)sender {
}

- (IBAction)reloadLabelsAction:(id)sender {
}

@end
