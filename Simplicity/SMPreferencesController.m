//
//  SMPreferencesController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMailLogin.h"
#import "SMPreferencesController.h"

#define kAccountName         @"PreferencesAccountName"
#define kFullUserName        @"PreferencesFullUserName"
#define kUserEmail           @"PreferencesUserEmail"
#define kImapServer          @"PreferencesImapServer"
#define kImapPort            @"PreferencesImapPort"
#define kImapUserName        @"PreferencesImapUserName"
#define kImapPassword        @"PreferencesImapPassword"
#define kImapConnectionType  @"PreferencesImapConnectionType"
#define kImapAuthType        @"PreferencesImapAuthType"
#define kSmtpServer          @"PreferencesSmtpServer"
#define kSmtpPort            @"PreferencesSmtpPort"
#define kSmtpUserName        @"PreferencesSmtpUserName"
#define kSmtpPassword        @"PreferencesSmtpPassword"
#define kSmtpConnectionType  @"PreferencesSmtpConnectionType"
#define kSmtpAuthType        @"PreferencesSmtpAuthType"

@implementation SMPreferencesController

+ (SMServerConnectionType)mcoToSMConnectionType:(MCOConnectionType)mcoConnectionType {
    switch(mcoConnectionType) {
        case MCOConnectionTypeClear:     return SMServerConnectionType_Clear;
        case MCOConnectionTypeStartTLS:  return SMServerConnectionType_StartTLS;
        case MCOConnectionTypeTLS:       return SMServerConnectionType_TLS;
    }
    
    SM_LOG_ERROR(@"Unknown mcoConnectionType %lu", mcoConnectionType);
    return SMServerConnectionType_Clear;
}

+ (MCOConnectionType)smToMCOConnectionType:(SMServerConnectionType)smConnectionType {
    switch(smConnectionType) {
        case SMServerConnectionType_Clear:     return MCOConnectionTypeClear;
        case SMServerConnectionType_StartTLS:  return MCOConnectionTypeStartTLS;
        case SMServerConnectionType_TLS:       return MCOConnectionTypeTLS;
    }
    
    SM_LOG_ERROR(@"Unknown smConnectionType %lu", smConnectionType);
    return MCOConnectionTypeClear;
}

+ (SMServerAuthType)mcoToSMAuthType:(MCOAuthType)mcoAuthType {
    switch(mcoAuthType) {
        case MCOAuthTypeSASLNone:       return SMServerAuthType_SASLNone;
        case MCOAuthTypeSASLCRAMMD5:    return SMServerAuthType_SASLCRAMMD5;
        case MCOAuthTypeSASLPlain:      return SMServerAuthType_SASLPlain;
        case MCOAuthTypeSASLGSSAPI:     return SMServerAuthType_SASLGSSAPI;
        case MCOAuthTypeSASLDIGESTMD5:  return SMServerAuthType_SASLDIGESTMD5;
        case MCOAuthTypeSASLLogin:      return SMServerAuthType_SASLLogin;
        case MCOAuthTypeSASLSRP:        return SMServerAuthType_SASLSRP;
        case MCOAuthTypeSASLNTLM:       return SMServerAuthType_SASLNTLM;
        case MCOAuthTypeSASLKerberosV4: return SMServerAuthType_SASLKerberosV4;
        case MCOAuthTypeXOAuth2:        return SMServerAuthType_XOAuth2;
        case MCOAuthTypeXOAuth2Outlook: return SMServerAuthType_XOAuth2Outlook;
    }
    
    SM_LOG_ERROR(@"Unknown mcoAuthType %lu", mcoAuthType);
    return SMServerAuthType_SASLNone;
}

+ (MCOAuthType)smToMCOAuthType:(SMServerAuthType)smAuthType {
    switch(smAuthType) {
        case SMServerAuthType_SASLNone:       return MCOAuthTypeSASLNone;
        case SMServerAuthType_SASLCRAMMD5:    return MCOAuthTypeSASLCRAMMD5;
        case SMServerAuthType_SASLPlain:      return MCOAuthTypeSASLPlain;
        case SMServerAuthType_SASLGSSAPI:     return MCOAuthTypeSASLGSSAPI;
        case SMServerAuthType_SASLDIGESTMD5:  return MCOAuthTypeSASLDIGESTMD5;
        case SMServerAuthType_SASLLogin:      return MCOAuthTypeSASLLogin;
        case SMServerAuthType_SASLSRP:        return MCOAuthTypeSASLSRP;
        case SMServerAuthType_SASLNTLM:       return MCOAuthTypeSASLNTLM;
        case SMServerAuthType_SASLKerberosV4: return MCOAuthTypeSASLKerberosV4;
        case SMServerAuthType_XOAuth2:        return MCOAuthTypeXOAuth2;
        case SMServerAuthType_XOAuth2Outlook: return MCOAuthTypeXOAuth2Outlook;
    }
    
    SM_LOG_ERROR(@"Unknown smAuthType %lu", smAuthType);
    return MCOAuthTypeSASLNone;
}

- (id)init {
    self = [super init];
    
    if(self) {
        
    }
    
    return self;
}

- (NSUInteger)accountsCount {
    return 1; // TODO
}

- (void)addAccountWithName:(NSString*)name {
    NSAssert(nil, @"TODO");
}

- (void)removeAccount:(NSUInteger)idx {
    NSAssert(nil, @"TODO");
}

- (void)setAccountName:(NSUInteger)idx name:(NSString*)name {
    // TODO
}

- (void)setFullUserName:(NSUInteger)idx userName:(NSString*)fullUserName {
    // TODO
}

- (void)setUserEmail:(NSUInteger)idx email:(NSString*)userEmail {
    // TODO
}

- (void)setImapServer:(NSUInteger)idx server:(NSString*)server {
    // TODO
}

- (void)setImapPort:(NSUInteger)idx port:(unsigned int)port {
    // TODO
}

- (void)setImapUserName:(NSUInteger)idx userName:(NSString*)imapUserName {
    // TODO
}

- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password {
    // TODO
}

- (void)setImapConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    // TODO
}

- (void)setImapAuthType:(NSUInteger)idx connectionType:(SMServerAuthType)authType {
    // TODO
}

- (void)setImapNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    // TODO
}

- (void)setSmtpServer:(NSUInteger)idx server:(NSString*)server {
    // TODO
}

- (void)setSmtpPort:(NSUInteger)idx port:(unsigned int)port {
    // TODO
}

- (void)setSmtpUserName:(NSUInteger)idx userName:(NSString*)imapUserName {
    // TODO
}

- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password {
    // TODO
}

- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    // TODO
}

- (void)setSmtpAuthType:(NSUInteger)idx connectionType:(SMServerAuthType)authType {
    // TODO
}

- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    // TODO
}

- (NSString*)accountName:(NSUInteger)idx {
    return @"Google"; // TODO
}

- (NSString*)fullUserName:(NSUInteger)idx {
    return @"Evgeny Baskakov"; // TODO
}

- (NSString*)userEmail:(NSUInteger)idx {
    return @"evgeny.baskakov@gmail.com"; // TODO
}

- (NSString*)imapServer:(NSUInteger)idx {
    return @"imap.gmail.com"; // TODO
}

- (unsigned int)imapPort:(NSUInteger)idx {
    return 993; // TODO
}

- (NSString*)imapUserName:(NSUInteger)idx {
    return [self userEmail:idx]; // TODO
}

- (NSString*)imapPassword:(NSUInteger)idx {
    return IMAP_PASSWORD; // TODO
}

- (SMServerConnectionType)imapConnectionType:(NSUInteger)idx {
    return SMServerConnectionType_TLS; // TODO
}

- (SMServerAuthType)imapAuthType:(NSUInteger)idx {
    return SMServerAuthType_SASLNone; // TODO
}

- (BOOL)imapNeedCheckCertificate:(NSUInteger)idx {
    return NO; // TODO
}

- (NSString*)smtpServer:(NSUInteger)idx {
    return @"smtp.gmail.com"; // TODO
}

- (unsigned int)smtpPort:(NSUInteger)idx {
    return 465; // TODO
}

- (NSString*)smtpUserName:(NSUInteger)idx {
    return [self userEmail:idx]; // TODO
}

- (NSString*)smtpPassword:(NSUInteger)idx {
    return SMTP_PASSWORD; // TODO
}

- (SMServerConnectionType)smtpConnectionType:(NSUInteger)idx {
    return SMServerConnectionType_TLS; // TODO
}

- (SMServerAuthType)smtpAuthType:(NSUInteger)idx {
    return SMServerAuthType_SASLLogin; // TODO
}

- (BOOL)smtpNeedCheckCertificate:(NSUInteger)idx {
    return NO; // TODO
}

@end
