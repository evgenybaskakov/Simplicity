//
//  SMMessageListToolbarViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/21/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMMessageListToolbarViewController : NSViewController

@property (nonatomic) IBOutlet NSButton *composeMessageButton;
@property (nonatomic) IBOutlet NSButton *trashButton;

@end
