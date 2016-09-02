//
//  SMURLChooserViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/30/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMURLChooserViewController : NSViewController<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *urlTextField;

@property (readonly) NSImage *chosenImage;

@property id target;
@property SEL actionOk;
@property SEL actionCancel;

@end
