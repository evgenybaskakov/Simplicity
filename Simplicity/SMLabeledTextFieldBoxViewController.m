//
//  SMLabeledTextFieldBoxViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLabeledTextFieldBoxViewController.h"

@implementation SMLabeledTextFieldBoxViewController

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
