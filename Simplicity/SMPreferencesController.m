//
//  SMPreferencesController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SSKeychain.h"

#import "SMLog.h"
#import "SMMailLogin.h"
#import "SMPreferencesController.h"

#define kSimplicityServiceName  @"com.simplicity.mail.service"

#define kServerTypeIMAP         @"IMAP"
#define kServerTypeSMTP         @"SMTP"

#define kAccountsCount              @"AccountsCount"
#define kAccountName                @"AccountName"
#define kFullUserName               @"FullUserName"
#define kUserEmail                  @"UserEmail"
#define kImapServer                 @"ImapServer"
#define kImapPort                   @"ImapPort"
#define kImapUserName               @"ImapUserName"
#define kImapConnectionType         @"ImapConnectionType"
#define kImapAuthType               @"ImapAuthType"
#define kImapNeedCheckCertificate   @"ImapNeedCheckCertificate"
#define kSmtpServer                 @"SmtpServer"
#define kSmtpPort                   @"SmtpPort"
#define kSmtpUserName               @"SmtpUserName"
#define kSmtpConnectionType         @"SmtpConnectionType"
#define kSmtpAuthType               @"SmtpAuthType"
#define kSmtpNeedCheckCertificate   @"SmtpNeedCheckCertificate"

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

+ (void)initialize {
    // TODO: register non-account related preferences
    
    NSDictionary *defaults = [NSDictionary dictionary];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (id)init {
    self = [super init];
    
    if(self) {
        
    }
    
    return self;
}

- (void)addAccountWithName:(NSString*)name {
    NSAssert(nil, @"TODO");
}

- (void)removeAccount:(NSUInteger)idx {
    NSAssert(nil, @"TODO");
}

- (void)setAccountName:(NSUInteger)idx name:(NSString*)name {
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:kAccountName];
}

- (void)setFullUserName:(NSUInteger)idx userName:(NSString*)fullUserName {
    [[NSUserDefaults standardUserDefaults] setObject:fullUserName forKey:kFullUserName];
}

- (void)setUserEmail:(NSUInteger)idx email:(NSString*)userEmail {
    [[NSUserDefaults standardUserDefaults] setObject:userEmail forKey:kUserEmail];
}

- (void)setImapServer:(NSUInteger)idx server:(NSString*)server {
    [[NSUserDefaults standardUserDefaults] setObject:server forKey:kImapServer];
}

- (void)setImapPort:(NSUInteger)idx port:(unsigned int)port {
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)port forKey:kImapPort];
}

- (void)setImapUserName:(NSUInteger)idx userName:(NSString*)userName {
    [[NSUserDefaults standardUserDefaults] setObject:userName forKey:kImapUserName];
}

- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeIMAP password:password];
}

- (void)setImapConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    [[NSUserDefaults standardUserDefaults] setInteger:connectionType forKey:kImapConnectionType];
}

- (void)setImapAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType {
    [[NSUserDefaults standardUserDefaults] setInteger:authType forKey:kImapAuthType];
}

- (void)setImapNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    [[NSUserDefaults standardUserDefaults] setBool:checkCertificate forKey:kImapNeedCheckCertificate];
}

- (void)setSmtpServer:(NSUInteger)idx server:(NSString*)server {
    [[NSUserDefaults standardUserDefaults] setObject:server forKey:kSmtpServer];
}

- (void)setSmtpPort:(NSUInteger)idx port:(unsigned int)port {
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)port forKey:kSmtpPort];
}

- (void)setSmtpUserName:(NSUInteger)idx userName:(NSString*)userName {
    [[NSUserDefaults standardUserDefaults] setObject:userName forKey:kSmtpUserName];
}

- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeSMTP password:password];
}

- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    [[NSUserDefaults standardUserDefaults] setInteger:connectionType forKey:kSmtpConnectionType];
}

- (void)setSmtpAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType {
    [[NSUserDefaults standardUserDefaults] setInteger:authType forKey:kSmtpAuthType];
}

- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    [[NSUserDefaults standardUserDefaults] setBool:checkCertificate forKey:kSmtpNeedCheckCertificate];
}

- (NSUInteger)accountsCount {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kAccountsCount];
}

- (NSString*)accountName:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kAccountName];
}

- (NSString*)fullUserName:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kFullUserName];
}

- (NSString*)userEmail:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kUserEmail];
}

- (NSString*)imapServer:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kImapServer];
}

- (unsigned int)imapPort:(NSUInteger)idx {
    return (unsigned int)[[NSUserDefaults standardUserDefaults] integerForKey:kImapPort];
}

- (NSString*)imapUserName:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kImapUserName];
}

- (NSString*)imapPassword:(NSUInteger)idx {
    return [self loadPassword:idx serverType:kServerTypeIMAP];
}

- (SMServerConnectionType)imapConnectionType:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kImapConnectionType];
}

- (SMServerAuthType)imapAuthType:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kImapAuthType];
}

- (BOOL)imapNeedCheckCertificate:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kImapNeedCheckCertificate];
}

- (NSString*)smtpServer:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kSmtpServer];
}

- (unsigned int)smtpPort:(NSUInteger)idx {
    return (unsigned int)[[NSUserDefaults standardUserDefaults] integerForKey:kSmtpPort];
}

- (NSString*)smtpUserName:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kSmtpUserName];
}

- (NSString*)smtpPassword:(NSUInteger)idx {
    return [self loadPassword:idx serverType:kServerTypeSMTP];
}

- (SMServerConnectionType)smtpConnectionType:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kSmtpConnectionType];
}

- (SMServerAuthType)smtpAuthType:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kSmtpAuthType];
}

- (BOOL)smtpNeedCheckCertificate:(NSUInteger)idx {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kSmtpNeedCheckCertificate];
}

- (void)savePassword:(NSUInteger)idx serverType:(NSString*)serverType password:(NSString*)password {
    NSString *accountName = [self accountName:idx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    [SSKeychain setPassword:password forService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Cannot save password for %@ account %@", serverType, accountName);
    }
}

- (NSString*)loadPassword:(NSUInteger)idx serverType:(NSString*)serverType {
    NSString *accountName = [self accountName:idx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    NSString *password = [SSKeychain passwordForService:kSimplicityServiceName account:serviceAccount];
    
    if(password == nil) {
        SM_LOG_ERROR(@"Cannot load password for %@ account %@", serverType, accountName);
        return @"";
    }
    
    return password;
}

@end
