//
//  SMMailboxToolbarViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/23/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMailboxToolbarViewController.h"

@interface SMMailboxToolbarViewController ()

@end

@implementation SMMailboxToolbarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self scaleImage:_addLabelButton];
}

- (void)scaleImage:(NSButton*)button {
    NSImage *img = [button image];
    NSSize buttonSize = [[button cell] cellSize];
    [img setSize:NSMakeSize(buttonSize.height/1.8, buttonSize.height/1.8)];
    [button setImage:img];
}

- (IBAction)addLabelButtonAction:(id)sender {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = [appDelegate appController];
    
    [appController showNewLabelSheet:nil];
}

@end
