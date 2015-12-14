//
//  SMFolderLabel.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMFolderLabel : NSObject<NSCoding>

@property NSString *name;
@property NSColor *color;
@property BOOL visible;

- (id)initWithName:(NSString*)name color:(NSColor*)color visible:(BOOL)visible;

@end
