//
//  SMTextMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/2/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMTextMessage : NSObject

@property (readonly) uint32_t uid;
@property (readonly) NSString *from;
@property (readonly) NSArray<NSString*> *toList;
@property (readonly) NSArray<NSString*> *ccList;
@property (readonly) NSString *subject;

- (id)initWithUID:(uint32_t)uid from:(NSString*)from toList:(NSArray<NSString*>*)toList ccList:(NSArray<NSString*>*)ccList subject:(NSString*)subject;

@end
