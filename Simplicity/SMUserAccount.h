//
//  SMUserAccount.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMUserAccount : NSObject

@property (readonly) NSUInteger accountIdx;

- (id)initWithIdx:(NSUInteger)idx;

@end
