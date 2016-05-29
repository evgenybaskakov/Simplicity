//
//  SMSearchToken.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMSearchExpressionKind.h"

@interface SMSearchToken : NSObject

@property SMSearchExpressionKind kind;
@property NSString *string;

- (id)initWithKind:(SMSearchExpressionKind)kind string:(NSString*)string;

@end
