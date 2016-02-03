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
@property (readonly) NSString *toList;
@property (readonly) NSString *ccList;
@property (readonly) NSString *subject;
@property (readonly) NSString *plainBodyText;

- (id)initWithUID:(uint32_t)uid from:(NSString*)from toList:(NSString*)toList ccList:(NSString*)ccList subject:(NSString*)subject plainBodyText:(NSString*)plainBodyText;

@end
