//
//  SMPreferencesController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SSKeychain.h"

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMMailLogin.h"
#import "SMMailServiceProvider.h"
#import "SMPreferencesController.h"

#define kSimplicityServiceName      @"com.simplicity.mail.service"

#define kServerTypeIMAP             @"IMAP"
#define kServerTypeSMTP             @"SMTP"

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
#if 0
        // TODO: Create a "clear settings" button.
        
        NSDictionary *allObjects = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        
        for(NSString *key in allObjects) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        }
        
        [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    }
    
    return self;
}

- (void)addAccountWithName:(NSString*)accountName image:(NSImage*)image userName:(NSString*)userName emailAddress:(NSString*)emailAddress provider:(SMMailServiceProvider*)provider {
    
    SM_LOG_INFO(@"New account '%@', userName '%@', emailAddress '%@'", accountName, userName, emailAddress);
    
    NSUInteger prevAccountCount = [self accountsCount];
    NSUInteger newAccountIdx = prevAccountCount;
    
    [[NSUserDefaults standardUserDefaults] setInteger:(prevAccountCount + 1) forKey:kAccountsCount];

    [self setAccountName:newAccountIdx name:accountName];
    [self setFullUserName:newAccountIdx userName:userName];
    [self setUserEmail:newAccountIdx email:emailAddress];
    
    [self setImapServer:newAccountIdx server:provider.imapServer];
    [self setImapPort:newAccountIdx port:provider.imapPort];
    [self setImapUserName:newAccountIdx userName:provider.imapUserName];
    [self setImapPassword:newAccountIdx password:provider.imapPassword];
    [self setImapConnectionType:newAccountIdx connectionType:provider.imapConnectionType];
    [self setImapAuthType:newAccountIdx authType:provider.imapAuthType];
    [self setImapNeedCheckCertificate:newAccountIdx checkCertificate:provider.imapNeedCheckCertificate];
    
    [self setSmtpServer:newAccountIdx server:provider.smtpServer];
    [self setSmtpPort:newAccountIdx port:provider.smtpPort];
    [self setSmtpUserName:newAccountIdx userName:provider.smtpUserName];
    [self setSmtpPassword:newAccountIdx password:provider.smtpPassword];
    [self setSmtpConnectionType:newAccountIdx connectionType:provider.smtpConnectionType];
    [self setSmtpAuthType:newAccountIdx authType:provider.smtpAuthType];
    [self setSmtpNeedCheckCertificate:newAccountIdx checkCertificate:provider.smtpNeedCheckCertificate];
    
    if(prevAccountCount == 0) {
        SM_LOG_INFO(@"Starting processing email account");
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

        [[appDelegate model] initServerSession];
        [[appDelegate model] getIMAPServerCapabilities];
        [[appDelegate appController] initOpExecutor];
    }
}

- (void)removeAccount:(NSUInteger)idx {
    NSAssert(nil, @"TODO");
}

- (void)setProperty:(NSString*)propertyName idx:(NSUInteger)idx obj:(NSObject*)obj {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
    if(newArr.count <= idx) {
        [newArr addObject:obj];
    }
    else {
        newArr[idx] = obj;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:newArr forKey:propertyName];
}

- (NSObject*)loadProperty:(NSString*)propertyName idx:(NSUInteger)idx {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    if(arr != nil && idx < arr.count) {
        return arr[idx];
    }
    else {
        SM_LOG_ERROR(@"Could not load property %@ for idx %lu", propertyName, idx);
        return nil;
    }
}

- (NSUInteger)accountsCount {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kAccountsCount];
}

- (void)setAccountName:(NSUInteger)idx name:(NSString*)name {
    [self setProperty:kAccountName idx:idx obj:name];
}

- (void)setFullUserName:(NSUInteger)idx userName:(NSString*)fullUserName {
    [self setProperty:kFullUserName idx:idx obj:fullUserName];
}

- (void)setUserEmail:(NSUInteger)idx email:(NSString*)userEmail {
    [self setProperty:kUserEmail idx:idx obj:userEmail];
}

- (void)setImapServer:(NSUInteger)idx server:(NSString*)server {
    [self setProperty:kImapServer idx:idx obj:server];
}

- (void)setImapPort:(NSUInteger)idx port:(unsigned int)port {
    [self setProperty:kImapPort idx:idx obj:[NSNumber numberWithUnsignedInt:port]];
}

- (void)setImapUserName:(NSUInteger)idx userName:(NSString*)userName {
    [self setProperty:kImapUserName idx:idx obj:userName];
}

- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeIMAP password:password];
}

- (void)setImapConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    [self setProperty:kImapConnectionType idx:idx obj:[NSNumber numberWithUnsignedInteger:connectionType]];
}

- (void)setImapAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType {
    [self setProperty:kImapAuthType idx:idx obj:[NSNumber numberWithUnsignedInteger:authType]];
}

- (void)setImapNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    [self setProperty:kImapNeedCheckCertificate idx:idx obj:[NSNumber numberWithUnsignedInteger:checkCertificate]];
}

- (void)setSmtpServer:(NSUInteger)idx server:(NSString*)server {
    [self setProperty:kSmtpServer idx:idx obj:server];
}

- (void)setSmtpPort:(NSUInteger)idx port:(unsigned int)port {
    [self setProperty:kSmtpPort idx:idx obj:[NSNumber numberWithUnsignedInt:port]];
}

- (void)setSmtpUserName:(NSUInteger)idx userName:(NSString*)userName {
    [self setProperty:kSmtpUserName idx:idx obj:userName];
}

- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeSMTP password:password];
}

- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    [self setProperty:kSmtpConnectionType idx:idx obj:[NSNumber numberWithUnsignedInteger:connectionType]];
}

- (void)setSmtpAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType {
    [self setProperty:kSmtpAuthType idx:idx obj:[NSNumber numberWithUnsignedInteger:authType]];
}

- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    [self setProperty:kSmtpNeedCheckCertificate idx:idx obj:[NSNumber numberWithUnsignedInteger:checkCertificate]];
}

- (NSString*)accountName:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kAccountName idx:idx];
}

- (NSString*)fullUserName:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kFullUserName idx:idx];
}

- (NSString*)userEmail:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kUserEmail idx:idx];
}

- (NSString*)imapServer:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kImapServer idx:idx];
}

- (unsigned int)imapPort:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kImapPort idx:idx] unsignedIntValue];
}

- (NSString*)imapUserName:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kImapUserName idx:idx];
}

- (NSString*)imapPassword:(NSUInteger)idx {
    return (NSString*)[self loadPassword:idx serverType:kServerTypeIMAP];
}

- (SMServerConnectionType)imapConnectionType:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kImapConnectionType idx:idx] unsignedIntegerValue];
}

- (SMServerAuthType)imapAuthType:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kImapAuthType idx:idx] unsignedIntegerValue];
}

- (BOOL)imapNeedCheckCertificate:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kImapNeedCheckCertificate idx:idx] unsignedIntegerValue];
}

- (NSString*)smtpServer:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kSmtpServer idx:idx];
}

- (unsigned int)smtpPort:(NSUInteger)idx {
    return (unsigned int)[self loadProperty:kSmtpPort idx:idx];
}

- (NSString*)smtpUserName:(NSUInteger)idx {
    return (NSString*)[self loadProperty:kSmtpUserName idx:idx];
}

- (NSString*)smtpPassword:(NSUInteger)idx {
    return [self loadPassword:idx serverType:kServerTypeSMTP];
}

- (SMServerConnectionType)smtpConnectionType:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kSmtpConnectionType idx:idx] unsignedIntegerValue];
}

- (SMServerAuthType)smtpAuthType:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kSmtpAuthType idx:idx] unsignedIntegerValue];
}

- (BOOL)smtpNeedCheckCertificate:(NSUInteger)idx {
    return [(NSNumber*)[self loadProperty:kSmtpNeedCheckCertificate idx:idx] unsignedIntegerValue];
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
