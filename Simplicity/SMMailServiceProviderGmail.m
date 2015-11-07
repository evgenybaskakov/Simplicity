//
//  SMMailServiceProviderGmailDesc.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/6/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMailServiceProviderGmail.h"

@implementation SMMailServiceProviderGmail

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
        imapServer = @"imap.gmail.com";
        imapPort = 993;
        imapConnectionType = SMServerConnectionType_TLS;
        imapAuthType = SMServerAuthType_SASLNone;
        imapNeedCheckCertificate = NO;

        smtpUserName = emailAddress;
        smtpPassword = password;
        smtpServer = @"smtp.gmail.com";
        smtpPort = 465;
        smtpConnectionType = SMServerConnectionType_TLS;
        smtpAuthType = SMServerAuthType_SASLLogin;
        smtpNeedCheckCertificate = NO;
    }
    
    return self;
}

@end
