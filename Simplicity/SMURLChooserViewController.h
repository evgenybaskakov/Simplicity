//
//  SMURLChooserViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/30/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMURLChooserViewController : NSViewController

@property (weak) IBOutlet NSTextField *promptLabel;
@property (weak) IBOutlet NSTextField *urlTextField;

@property NSArray<NSString*> *allowedFileTypes;
@property id target;
@property SEL actionOk;
@property SEL actionCancel;

@end
