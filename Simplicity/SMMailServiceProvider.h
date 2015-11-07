//
//  SMMailServiceProviderDesc.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/6/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SMServerConnectionType) {
    SMServerConnectionType_Clear,
    SMServerConnectionType_StartTLS,
    SMServerConnectionType_TLS,
};

typedef NS_ENUM(NSInteger, SMServerAuthType) {
    SMServerAuthType_SASLNone,
    SMServerAuthType_SASLCRAMMD5,
    SMServerAuthType_SASLPlain,
    SMServerAuthType_SASLGSSAPI,
    SMServerAuthType_SASLDIGESTMD5,
    SMServerAuthType_SASLLogin,
    SMServerAuthType_SASLSRP,
    SMServerAuthType_SASLNTLM,
    SMServerAuthType_SASLKerberosV4,
    SMServerAuthType_XOAuth2,
    SMServerAuthType_XOAuth2Outlook,
};

@interface SMMailServiceProvider : NSObject

@property (readonly) NSString *imapServer;
@property (readonly) unsigned int imapPort;
@property (readonly) NSString *imapUserName;
@property (readonly) NSString *imapPassword;
@property (readonly) SMServerConnectionType imapConnectionType;
@property (readonly) SMServerAuthType imapAuthType;
@property (readonly) BOOL imapNeedCheckCertificate;

@property (readonly) NSString *smtpServer;
@property (readonly) unsigned int smtpPort;
@property (readonly) NSString *smtpUserName;
@property (readonly) NSString *smtpPassword;
@property (readonly) SMServerConnectionType smtpConnectionType;
@property (readonly) SMServerAuthType smtpAuthType;
@property (readonly) BOOL smtpNeedCheckCertificate;

@end
