//
//  SMMessageEditorBase.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMMessageEditorBase : NSObject

+ (NSArray*)fontFamilies;
+ (NSArray*)fontNames;
+ (NSDictionary*)fontNameToIndexMap;
+ (NSString*)newMessageHTMLBeginTemplate;
+ (NSString*)newMessageHTMLEndTemplate;

- (NSColor*)colorFromString:(NSString*)colorString;

@end
