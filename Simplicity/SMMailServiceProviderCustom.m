//
//  SMMailServiceProviderCustom.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/6/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMailServiceProviderCustom.h"

@implementation SMMailServiceProviderCustom

@synthesize imapServer;
@synthesize imapPort;
@synthesize imapUserName;
@synthesize imapPassword;
@synthesize imapConnectionType;
@synthesize imapAuthType;
@synthesize imapNeedCheckCertificate;

@synthesize smtpServer;
@synthesize smtpPort;
@synthesize smtpUserName;
@synthesize smtpPassword;
@synthesize smtpConnectionType;
@synthesize smtpAuthType;
@synthesize smtpNeedCheckCertificate;

- (id)initWithEmailAddress:(NSString*)emailAddress password:(NSString*)password {
    self = [super init];
    
    if(self) {
        imapUserName = emailAddress;
        imapPassword = password;
        imapServer = @"";
        imapPort = 0;
        imapConnectionType = SMServerConnectionType_Clear;
        imapAuthType = SMServerAuthType_SASLNone;
        imapNeedCheckCertificate = NO;
        
        smtpUserName = emailAddress;
        smtpPassword = password;
        smtpServer = @"";
        smtpPort = 0;
        smtpConnectionType = SMServerConnectionType_Clear;
        smtpAuthType = SMServerAuthType_SASLNone;
        smtpNeedCheckCertificate = NO;
    }
    
    return self;
}

@end
