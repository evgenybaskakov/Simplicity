//
//  SMButtonWithMenu.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMButtonWithLongClickAction : NSButton

@property SEL longClickAction;

@end
