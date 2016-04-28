//
//  SMMessageEditorToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/25/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageEditorViewController.h"
#import "SMMessageEditorToolbarViewController.h"

@implementation SMMessageEditorToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)sendAction:(id)sender {
    [_messageEditorViewController sendMessage];
}

- (IBAction)deleteAction:(id)sender {
    [_messageEditorViewController deleteEditedDraft];
}

- (IBAction)attachAction:(id)sender {
    [_messageEditorViewController attachDocument];
}

@end
