//
//  SMAccountConnectionController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/9/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMAccountConnectionController : NSObject

- (id)initWithUserAccount:(SMUserAccount*)account;

- (void)startIdle;
- (void)stopIdle;
- (void)stopReachabilityMonitor;

@end
