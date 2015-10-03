//
//  SMMessageThreadDescriptor.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/2/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessageThread;

@interface SMMessageThreadDescriptor : NSObject

@property (readonly) uint64_t threadId;
@property (readonly) NSUInteger messagesCount;
@property (readonly) NSArray *entries;

- (id)initWithMessageThread:(SMMessageThread*)messageThread;

@end
