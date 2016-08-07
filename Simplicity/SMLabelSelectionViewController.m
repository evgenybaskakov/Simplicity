//
//  SMLabelSelectionViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

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
    return 10; // TODO
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SMLabelSelectionRow *view = [tableView makeViewWithIdentifier:@"LabelSelectionRow" owner:self];
    NSAssert(view != nil, @"view is nil");
    
    return view;
}

@end
