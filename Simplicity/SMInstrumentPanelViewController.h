//
//  SMInstrumentPanelViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/26/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMInstrumentPanelViewController : NSViewController

@property IBOutlet NSView *workView;

/*
- (IBAction)hideSearchResults:(id)sender;
*/
- (IBAction)addNewLabel:(id)sender;
- (IBAction)showOperationQueue:(id)sender;

@end
