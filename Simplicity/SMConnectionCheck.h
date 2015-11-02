//
//  SMConnectionCheck.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/1/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SMConnectionStatus) {
    SMConnectionStatus_NotConnected,
    SMConnectionStatus_Connected,
    SMConnectionStatus_ConnectionFailed,
    SMConnectionStatus_AuthFailed,
};

@interface SMConnectionCheck : NSObject

- (void)checkImapConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock;
- (void)checkSmtpConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock;

@end
