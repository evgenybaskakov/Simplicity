//
//  SMSearchToken.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SearchExpressionKind) {
    SearchExpressionKind_To,
    SearchExpressionKind_From,
    SearchExpressionKind_Cc,
    SearchExpressionKind_Subject,
    SearchExpressionKind_Content,
    SearchExpressionKind_Any,
};

@interface SMSearchToken : NSObject

@property SearchExpressionKind kind;
@property NSString *string;

- (id)initWithKind:(SearchExpressionKind)kind string:(NSString*)string;

@end
