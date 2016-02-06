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
    SearchExpressionKind_Contents,
};

@interface SMSearchToken : NSObject

@property (readonly) SearchExpressionKind kind;
@property (readonly) NSString *string;

- (id)initWithKind:(SearchExpressionKind)kind string:(NSString*)string;

@end
