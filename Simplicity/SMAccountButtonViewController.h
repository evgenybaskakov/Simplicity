//
//  SMAccountButtonViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/12/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMAccountButtonViewController : NSViewController

@property (weak) IBOutlet NSImageView *accountImage;
@property (weak) IBOutlet NSTextField *accountName;

@property NSUInteger accountIdx;

@end