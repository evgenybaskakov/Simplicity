//
//  SMUserAccount.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMSimplicityContainer;

@interface SMUserAccount : NSObject

@property (readonly) NSUInteger accountIdx;
@property (readonly) SMSimplicityContainer __weak *model; // TODO: remove __weak

- (id)initWithIdx:(NSUInteger)idx model:(SMSimplicityContainer*)model;

@end
