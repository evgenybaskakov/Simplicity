//
//  SMSearchContentsPanelViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessageThreadViewController.h"
#import "SMFindContentsPanelViewController.h"

@implementation SMFindContentsPanelViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        ;
    }
    
    return self;
}

- (IBAction)findContentsSearchAction:(id)sender {
    const Boolean matchCase = (_matchCaseCheckbox.state == NSOnState);
    [self doFindContentsSearch:_searchField.stringValue matchCase:matchCase forward:YES restart:NO];
}

- (IBAction)setMatchCaseAction:(id)sender {
    const Boolean matchCase = (_matchCaseCheckbox.state == NSOnState);
    [self doFindContentsSearch:_searchField.stringValue matchCase:matchCase forward:YES restart:YES];
}

- (IBAction)findNextPrevAction:(id)sender {
    const Boolean matchCase = (_matchCaseCheckbox.state == NSOnState);
        
    if([_forwardBackwardsButton selectedSegment] == 0) {
        [self doFindContentsSearch:_searchField.stringValue matchCase:matchCase forward:NO restart:NO];
    } else if([_forwardBackwardsButton selectedSegment] == 1) {
        [self doFindContentsSearch:_searchField.stringValue matchCase:matchCase forward:YES restart:NO];
    }
}

- (void)doFindContentsSearch:(NSString*)stringToFind matchCase:(Boolean)matchCase forward:(Boolean)forward restart:(Boolean)restart {
    if(restart) {
        [_messageThreadViewController removeFindContentsResults];
    }
    
    [_messageThreadViewController findContents:stringToFind matchCase:matchCase forward:forward];
}

- (IBAction)doneAction:(id)sender {
    [_messageThreadViewController hideFindContentsPanel];
}

@end
