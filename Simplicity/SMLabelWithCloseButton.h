//
//  SMLabelWithCloseButton.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/3/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMLabelWithCloseButton : NSViewController

@property (nonatomic) NSString *text;
@property (nonatomic) NSColor *color;
@property (nonatomic) id target;
@property (nonatomic) SEL action;
@property (nonatomic) NSObject *object;

@end
