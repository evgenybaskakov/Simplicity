//
//  SMPreferencesController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

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

@interface SMPreferencesController : NSObject

+ (SMServerConnectionType)mcoToSMConnectionType:(MCOConnectionType)mcoConnectionType;
+ (MCOConnectionType)smToMCOConnectionType:(SMServerConnectionType)smConnectionType;

+ (SMServerAuthType)mcoToSMAuthType:(MCOAuthType)mcoAuthType;
+ (MCOAuthType)smToMCOAuthType:(SMServerAuthType)smAuthType;

- (NSUInteger)accountsCount;

- (void)addAccountWithName:(NSString*)name;
- (void)removeAccount:(NSUInteger)idx;

- (void)setAccountName:(NSUInteger)idx name:(NSString*)name;
- (void)setFullUserName:(NSUInteger)idx userName:(NSString*)fullUserName;
- (void)setUserEmail:(NSUInteger)idx email:(NSString*)userEmail;

- (void)setImapServer:(NSUInteger)idx server:(NSString*)server;
- (void)setImapPort:(NSUInteger)idx port:(unsigned int)port;
- (void)setImapUserName:(NSUInteger)idx userName:(NSString*)imapUserName;
- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password;
- (void)setImapConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType;
- (void)setImapAuthType:(NSUInteger)idx connectionType:(SMServerAuthType)authType;
- (void)setImapNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate;

- (void)setSmtpServer:(NSUInteger)idx server:(NSString*)server;
- (void)setSmtpPort:(NSUInteger)idx port:(unsigned int)port;
- (void)setSmtpUserName:(NSUInteger)idx userName:(NSString*)imapUserName;
- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password;
- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType;
- (void)setSmtpAuthType:(NSUInteger)idx connectionType:(SMServerAuthType)authType;
- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate;

- (NSString*)accountName:(NSUInteger)idx;
- (NSString*)fullUserName:(NSUInteger)idx;
- (NSString*)userEmail:(NSUInteger)idx;

- (NSString*)imapServer:(NSUInteger)idx;
- (unsigned int)imapPort:(NSUInteger)idx;
- (NSString*)imapUserName:(NSUInteger)idx;
- (NSString*)imapPassword:(NSUInteger)idx;
- (SMServerConnectionType)imapConnectionType:(NSUInteger)idx;
- (SMServerAuthType)imapAuthType:(NSUInteger)idx;
- (BOOL)imapNeedCheckCertificate:(NSUInteger)idx;

- (NSString*)smtpServer:(NSUInteger)idx;
- (unsigned int)smtpPort:(NSUInteger)idx;
- (NSString*)smtpUserName:(NSUInteger)idx;
- (NSString*)smtpPassword:(NSUInteger)idx;
- (SMServerConnectionType)smtpConnectionType:(NSUInteger)idx;
- (SMServerAuthType)smtpAuthType:(NSUInteger)idx;
- (BOOL)smtpNeedCheckCertificate:(NSUInteger)idx;

@end
