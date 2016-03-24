//
//  SMLabeledPopUpListViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/23/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLabeledPopUpListViewController.h"

@implementation SMLabeledPopUpListViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSView *view = [self view];
    
    NSAssert([view isKindOfClass:[NSBox class]], @"view not NSBox");
    
    [(NSBox*)view setBoxType:NSBoxCustom];
    [(NSBox*)view setTitlePosition:NSNoTitle];
    [(NSBox*)view setFillColor:[NSColor whiteColor]];
    [(NSBox*)view setBorderColor:[NSColor lightGrayColor]];
}

@end
