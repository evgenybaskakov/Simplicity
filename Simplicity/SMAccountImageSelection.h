//
//  SMAccountImageSelection.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/10/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMAccountImageSelection : NSObject

+ (NSImage*)defaultImage;
+ (NSImage*)promptForImage;

@end
