//
//  SMMessageEditorWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/25/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageEditorViewController.h"
#import "SMMessageEditorWindowController.h"

@implementation SMMessageEditorWindowController {
    SMMessageEditorViewController *_messageEditorViewController;
}

- (void)awakeFromNib {
    _messageEditorViewController = [[SMMessageEditorViewController alloc] initWithNibName:@"SMMessageEditorViewController" bundle:nil embedded:NO];

    NSAssert(_messageEditorViewController != nil, @"_messageEditorViewController is nil");
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Delegate setup

    [[self window] setDelegate:self];
    
    // View setup

    [[self window] setContentView:_messageEditorViewController.view];
}

#pragma mark Actions

//- (BOOL)windowShouldClose:(id)sender {
//    NSLog(@"%s", __func__);
//    return YES;
//}

- (void)windowWillClose:(NSNotification *)notification {
    [_messageEditorViewController closeEditor];
}

@end
