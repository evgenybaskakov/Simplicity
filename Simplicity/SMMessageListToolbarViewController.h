//
//  SMMessageListToolbarViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMMessageListToolbarViewController : NSViewController

@property (weak) IBOutlet NSButton *composeMessageButton;
@property (weak) IBOutlet NSButton *trashButton;
@property (weak) IBOutlet NSButton *starButton;

@end
