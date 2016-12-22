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

    [self scaleImage:_attachButton];
    [self scaleImage:_deleteButton];
    [self scaleImage:_makeWindowButton];
}

- (void)scaleImage:(NSButton*)button {
    NSImage *img = [button image];
    NSSize buttonSize = [[button cell] cellSize];
    [img setSize:NSMakeSize(buttonSize.height/1.7, buttonSize.height/1.7)];
    [button setImage:img];
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

- (IBAction)makeWindowAction:(id)sender {
    [_messageEditorViewController makeWindow];
}

@end
