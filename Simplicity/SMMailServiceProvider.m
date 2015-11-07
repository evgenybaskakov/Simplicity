//
//  SMMailServiceProviderDesc.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/6/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMailServiceProvider.h"

@implementation SMMailServiceProvider

- (id)init {
    self = [super init];
    
    if(self) {
        _imapPort = 0;
        _imapConnectionType = SMServerConnectionType_Clear;
        _imapAuthType = SMServerAuthType_SASLNone;
        _imapNeedCheckCertificate = NO;
        
        _smtpPort = 0;
        _smtpConnectionType = SMServerConnectionType_Clear;
        _smtpAuthType = SMServerAuthType_SASLNone;
        _smtpNeedCheckCertificate = NO;
    }
    
    return self;
}

@end
