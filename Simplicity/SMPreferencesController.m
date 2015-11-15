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
#import "SMAccountImageSelection.h"
#import "SMPreferencesController.h"

#define kSimplicityServiceName          @"com.simplicity.mail.service"

#define kServerTypeIMAP                 @"IMAP"
#define kServerTypeSMTP                 @"SMTP"

#define kAccountsCount                  @"AccountsCount"
#define kAccountName                    @"AccountName"
#define kFullUserName                   @"FullUserName"
#define kUserEmail                      @"UserEmail"
#define kImapServer                     @"ImapServer"
#define kImapPort                       @"ImapPort"
#define kImapUserName                   @"ImapUserName"
#define kImapConnectionType             @"ImapConnectionType"
#define kImapAuthType                   @"ImapAuthType"
#define kImapNeedCheckCertificate       @"ImapNeedCheckCertificate"
#define kSmtpServer                     @"SmtpServer"
#define kSmtpPort                       @"SmtpPort"
#define kSmtpUserName                   @"SmtpUserName"
#define kSmtpConnectionType             @"SmtpConnectionType"
#define kSmtpAuthType                   @"SmtpAuthType"
#define kSmtpNeedCheckCertificate       @"SmtpNeedCheckCertificate"
#define kShouldShowContactImages        @"ShouldShowContactImages"
#define kMessageListPreviewLineCount    @"MessageListPreviewLineCount"
#define kMessageCheckPeriodSec          @"MessageCheckPeriodSec"
#define kDownloadsFolder                @"DownloadsFolder"

@implementation SMPreferencesController {
    BOOL _shouldShowContactImagesCached;
    NSUInteger _messageListPreviewLineCountCached;
    NSUInteger _messageCheckPeriodSecCached;
    NSString *_downloadsFolderCached;
}

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
    
    [self setAccountName:newAccountIdx name:accountName];
    [self setFullUserName:newAccountIdx userName:userName];
    [self setUserEmail:newAccountIdx email:emailAddress];
    
    [self setImapServer:newAccountIdx server:provider.imapServer];
    [self setImapPort:newAccountIdx port:provider.imapPort];
    [self setImapUserName:newAccountIdx userName:provider.imapUserName];
    [self setImapConnectionType:newAccountIdx connectionType:provider.imapConnectionType];
    [self setImapAuthType:newAccountIdx authType:provider.imapAuthType];
    [self setImapNeedCheckCertificate:newAccountIdx checkCertificate:provider.imapNeedCheckCertificate];
    
    [self setSmtpServer:newAccountIdx server:provider.smtpServer];
    [self setSmtpPort:newAccountIdx port:provider.smtpPort];
    [self setSmtpUserName:newAccountIdx userName:provider.smtpUserName];
    [self setSmtpConnectionType:newAccountIdx connectionType:provider.smtpConnectionType];
    [self setSmtpAuthType:newAccountIdx authType:provider.smtpAuthType];
    [self setSmtpNeedCheckCertificate:newAccountIdx checkCertificate:provider.smtpNeedCheckCertificate];

    [self setImapPassword:newAccountIdx password:provider.imapPassword];
    [self setSmtpPassword:newAccountIdx password:provider.smtpPassword];

    // Increment account acount after evething is set.
    [[NSUserDefaults standardUserDefaults] setInteger:(prevAccountCount + 1) forKey:kAccountsCount];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Create cache directory.
    NSString *cacheDirPath = [self cacheDirPath:newAccountIdx];

    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:cacheDirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        SM_LOG_ERROR(@"failed to create cache directory '%@', error: %@", cacheDirPath, error);
    }

    // Save the account image;
    if(image != nil) {
        NSString *accountImagePath = [self accountImagePath:newAccountIdx];
        NSAssert(accountImagePath != nil, @"accountImagePath is nil");
    
        [SMAccountImageSelection saveImageFile:accountImagePath image:image];
    }
    
    // Now start normal account operationing.
    if(prevAccountCount == 0) {
        SM_LOG_INFO(@"Starting processing email account");
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        
        [[appDelegate model] initAccountSession];
        [[appDelegate model] getIMAPServerCapabilities];
        
        [[appDelegate appController] initOpExecutor];
    }
}

- (void)removeAccount:(NSUInteger)idx {
    NSUInteger accountCount = [self accountsCount];
    NSAssert(idx < accountCount, @"bad idx %lu, account count %lu", idx, accountCount);
    
    NSError *error = nil;

    NSString *accountImageFilePath = [self accountImagePath:idx];
    [[NSFileManager defaultManager] removeItemAtPath:accountImageFilePath error:&error];
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Could not remove '%@', error '%@'", accountImageFilePath, error);
    }

    NSString *accountDatabaseFilePath = [self databaseFilePath:idx];
    [[NSFileManager defaultManager] removeItemAtPath:accountDatabaseFilePath error:&error];
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Could not remove '%@', error '%@'", accountDatabaseFilePath, error);
    }

    NSString *cacheDirPath = [self cacheDirPath:idx];
    if(![[NSFileManager defaultManager] removeItemAtPath:cacheDirPath error:&error]) {
        SM_LOG_ERROR(@"Could not remove cache directory '%@', error: %@", cacheDirPath, error);
    }

    NSString *accountDirPath = [self accountDirPath:idx];
    if(![[NSFileManager defaultManager] removeItemAtPath:accountDirPath error:&error]) {
        SM_LOG_ERROR(@"Could not remove account directory '%@', error: %@", accountDirPath, error);
    }

    [self removePassword:idx serverType:kServerTypeIMAP];
    [self removePassword:idx serverType:kServerTypeSMTP];

    [self removeProperty:kAccountName idx:idx];
    [self removeProperty:kFullUserName idx:idx];
    [self removeProperty:kUserEmail idx:idx];
    [self removeProperty:kImapServer idx:idx];
    [self removeProperty:kImapPort idx:idx];
    [self removeProperty:kImapUserName idx:idx];
    [self removeProperty:kImapConnectionType idx:idx];
    [self removeProperty:kImapAuthType idx:idx];
    [self removeProperty:kImapNeedCheckCertificate idx:idx];
    [self removeProperty:kSmtpServer idx:idx];
    [self removeProperty:kSmtpPort idx:idx];
    [self removeProperty:kSmtpUserName idx:idx];
    [self removeProperty:kSmtpConnectionType idx:idx];
    [self removeProperty:kSmtpAuthType idx:idx];
    [self removeProperty:kSmtpNeedCheckCertificate idx:idx];
    
    [[NSUserDefaults standardUserDefaults] setInteger:(accountCount - 1) forKey:kAccountsCount];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)renameAccount:(NSUInteger)idx newName:(NSString*)newName {
    NSString *accountDirPath = [self accountDirPath:idx];
    NSString *newAccountDirPath = [[accountDirPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];

    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtPath:accountDirPath toPath:newAccountDirPath error:&error];
    
    if(error && error.code != noErr) {
        SM_LOG_ERROR(@"Could not rename account '%@' to '%@': %@", [self accountName:idx], newName, error.localizedDescription);
        return FALSE;
    }
    
    NSString *imapPassword = [self imapPassword:idx];
    NSString *smtpPassword = [self smtpPassword:idx];
    
    [self removePassword:idx serverType:kServerTypeIMAP];
    [self removePassword:idx serverType:kServerTypeSMTP];
    
    [self setAccountName:idx name:newName];
    
    [self setImapPassword:idx password:imapPassword];
    [self setSmtpPassword:idx password:smtpPassword];

    return TRUE;
}

- (BOOL)accountExists:(NSString*)accountName {
    NSUInteger accountCount = [self accountsCount];
    
    for(NSUInteger i = 0; i < accountCount; i++) {
        if([[self accountName:i] isEqualToString:accountName]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSUInteger)accountsCount {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kAccountsCount];
}

#pragma Property accessors

- (void)setProperty:(NSString*)propertyName idx:(NSUInteger)idx obj:(NSObject*)obj {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
    if(newArr.count <= idx) {
        while(newArr.count <= idx) {
            [newArr addObject:obj];
        }
    }
    else {
        newArr[idx] = obj;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:newArr forKey:propertyName];
}

- (void)removeProperty:(NSString*)propertyName idx:(NSUInteger)idx {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    if(idx < arr.count) {
        NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
        [newArr removeObjectAtIndex:idx];
    
        [[NSUserDefaults standardUserDefaults] setObject:newArr forKey:propertyName];
    }
    else {
        SM_LOG_ERROR(@"Could not remove property %@ for idx %lu", propertyName, idx);
    }
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

#pragma mark Property setters

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

- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType {
    [self setProperty:kSmtpConnectionType idx:idx obj:[NSNumber numberWithUnsignedInteger:connectionType]];
}

- (void)setSmtpAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType {
    [self setProperty:kSmtpAuthType idx:idx obj:[NSNumber numberWithUnsignedInteger:authType]];
}

- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate {
    [self setProperty:kSmtpNeedCheckCertificate idx:idx obj:[NSNumber numberWithUnsignedInteger:checkCertificate]];
}

#pragma mark Property getters

- (NSString*)accountName:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kAccountName idx:idx];
    return str? str : @"";
}

- (NSString*)fullUserName:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kFullUserName idx:idx];
    return str? str : @"";
}

- (NSString*)userEmail:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kUserEmail idx:idx];
    return str? str : @"";
}

- (NSURL*)accountDirURL:(NSUInteger)idx {
    NSURL* appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    NSString *accountName = [self accountName:idx];
    NSAssert(accountName != nil && accountName.length > 0, @"bad account name");
    
    return [appDataDir URLByAppendingPathComponent:accountName isDirectory:YES];
}

- (NSString*)accountDirPath:(NSUInteger)idx {
    return [[self accountDirURL:idx] path];
}

- (NSString*)accountImagePath:(NSUInteger)idx {
    NSURL *accountUrl = [self accountDirURL:idx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Image.png"] isDirectory:NO];
    NSAssert(url, @"no image url");
    
    return [url path];
}

- (NSString*)databaseFilePath:(NSUInteger)idx {
    NSURL *accountUrl = [self accountDirURL:idx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Database.sqlite"] isDirectory:NO];
    NSAssert(url, @"no data url");
    
    return [url path];
}

- (NSString*)cacheDirPath:(NSUInteger)idx {
    NSURL *accountUrl = [self accountDirURL:idx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Cache"] isDirectory:YES];
    NSAssert(url, @"no data url");
    
    return [url path];
}

- (NSString*)imapServer:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kImapServer idx:idx];
    return str? str : @"";
}

- (unsigned int)imapPort:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapPort idx:idx];
    return number? [number unsignedIntValue] : 0;
}

- (NSString*)imapUserName:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kImapUserName idx:idx];
    return str? str : @"";
}

- (SMServerConnectionType)imapConnectionType:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapConnectionType idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

- (SMServerAuthType)imapAuthType:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapAuthType idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

- (BOOL)imapNeedCheckCertificate:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapNeedCheckCertificate idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

- (NSString*)smtpServer:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kSmtpServer idx:idx];
    return str? str : @"";
}

- (unsigned int)smtpPort:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpPort idx:idx];
    return number? [number unsignedIntValue] : 0;
}

- (NSString*)smtpUserName:(NSUInteger)idx {
    NSString *str = (NSString*)[self loadProperty:kSmtpUserName idx:idx];
    return str? str : @"";
}

- (SMServerConnectionType)smtpConnectionType:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpConnectionType idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

- (SMServerAuthType)smtpAuthType:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpAuthType idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

- (BOOL)smtpNeedCheckCertificate:(NSUInteger)idx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpNeedCheckCertificate idx:idx];
    return number? [number unsignedIntegerValue] : 0;
}

#pragma mark Password management

- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeIMAP password:password];
}

- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password {
    [self savePassword:idx serverType:kServerTypeSMTP password:password];
}

- (NSString*)imapPassword:(NSUInteger)idx {
    NSString *str = [self loadPassword:idx serverType:kServerTypeIMAP];
    return str? str : @"";
}

- (NSString*)smtpPassword:(NSUInteger)idx {
    NSString *str = [self loadPassword:idx serverType:kServerTypeSMTP];
    return str? str : @"";
}

#pragma mark Secured data accessors

- (void)savePassword:(NSUInteger)idx serverType:(NSString*)serverType password:(NSString*)password {
    NSString *accountName = [self accountName:idx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    [SSKeychain setPassword:password forService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Cannot save password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
    }
}

- (NSString*)loadPassword:(NSUInteger)idx serverType:(NSString*)serverType {
    NSString *accountName = [self accountName:idx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if((error != nil && error.code != noErr) || password == nil) {
        SM_LOG_ERROR(@"Cannot load password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
        return @"";
    }
    
    return password;
}

- (void)removePassword:(NSUInteger)idx serverType:(NSString*)serverType {
    NSString *accountName = [self accountName:idx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    [SSKeychain deletePasswordForService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Cannot delete password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
    }
}

#pragma mark Should show contact images in message list

- (BOOL)shouldShowContactImages {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldShowContactImages] == nil) {
            _shouldShowContactImagesCached = YES;

            SM_LOG_INFO(@"Using default kShouldShowContactImages: %@", _shouldShowContactImagesCached? @"YES" : @"NO");
        }
        else {
            _shouldShowContactImagesCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldShowContactImages]);
            
            SM_LOG_INFO(@"Loaded kShouldShowContactImages: %@", _shouldShowContactImagesCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }

    return _shouldShowContactImagesCached;
}

- (void)setShouldShowContactImages:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:kShouldShowContactImages];

    _shouldShowContactImagesCached = flag;
}

#pragma mark Message list preview lines

- (NSUInteger)messageListPreviewLineCount {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kMessageListPreviewLineCount] == nil) {
            _messageListPreviewLineCountCached = 2;
            
            SM_LOG_INFO(@"Using default _messageListPreviewLineCountCached: %lu", _messageListPreviewLineCountCached);
        }
        else {
            _messageListPreviewLineCountCached = [[NSUserDefaults standardUserDefaults] integerForKey:kMessageListPreviewLineCount];
            
            SM_LOG_INFO(@"Loaded _messageListPreviewLineCountCached: %lu", _messageListPreviewLineCountCached);
        }
        
        skipUserDefaults = YES;
    }
    
    return _messageListPreviewLineCountCached;
}

- (void)setMessageListPreviewLineCount:(NSUInteger)count {
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:kMessageListPreviewLineCount];

    _messageListPreviewLineCountCached = count;
}

#pragma mark Messages check period

- (NSUInteger)messageCheckPeriodSec {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kMessageCheckPeriodSec] == nil) {
            _messageCheckPeriodSecCached = 0;
            
            SM_LOG_INFO(@"Using default _messageCheckPeriodSecCached: %lu", _messageCheckPeriodSecCached);
        }
        else {
            _messageCheckPeriodSecCached = [[NSUserDefaults standardUserDefaults] integerForKey:kMessageCheckPeriodSec];
            
            SM_LOG_INFO(@"Loaded _messageCheckPeriodSecCached: %lu", _messageCheckPeriodSecCached);
        }
        
        skipUserDefaults = YES;
    }
    
    return _messageCheckPeriodSecCached;
}

- (void)setMessageCheckPeriodSec:(NSUInteger)sec {
    [[NSUserDefaults standardUserDefaults] setInteger:sec forKey:kMessageCheckPeriodSec];
    
    _messageCheckPeriodSecCached = sec;
}

#pragma mark Downloads folder

- (NSString*)downloadsFolder {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        _downloadsFolderCached = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:kDownloadsFolder];
        
        if(_downloadsFolderCached != nil) {
            BOOL isDir = NO;
            BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:_downloadsFolderCached isDirectory:&isDir];
         
            if(pathExists) {
                if(!isDir) {
                    SM_LOG_WARNING(@"Loaded downloads folder path '%@' is not a directory", _downloadsFolderCached);
                    _downloadsFolderCached = nil;
                }
            }
            else {
                SM_LOG_WARNING(@"Loaded downloads folder path '%@' does not exist", _downloadsFolderCached);
                _downloadsFolderCached = nil;
            }
        }
        
        if(_downloadsFolderCached == nil) {
            NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
            if(docDirs.count > 0) {
                _downloadsFolderCached = [docDirs objectAtIndex:0];
            }
            else {
                _downloadsFolderCached = @"/";
            }
            
            SM_LOG_INFO(@"Using default _downloadsFolderCached: %@", _downloadsFolderCached);
        }
        else {
            
            SM_LOG_INFO(@"Using loaded _downloadsFolderCached: %@", _downloadsFolderCached);
        }
        
        skipUserDefaults = YES;
    }
    
    return _downloadsFolderCached;
}

- (void)setDownloadsFolder:(NSString*)folder {
    [[NSUserDefaults standardUserDefaults] setObject:folder forKey:kDownloadsFolder];

    _downloadsFolderCached = folder;
}

@end
