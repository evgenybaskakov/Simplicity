//
//  SMSearchExpressionKind.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SMSearchExpressionKind) {
    SMSearchExpressionKind_To,
    SMSearchExpressionKind_From,
    SMSearchExpressionKind_Cc,
    SMSearchExpressionKind_Subject,
    SMSearchExpressionKind_Content,
    SMSearchExpressionKind_Any,
};
