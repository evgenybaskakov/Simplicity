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
#import "SMUserAccount.h"
#import "SMMailServiceProvider.h"
#import "SMAccountImageSelection.h"
#import "SMPreferencesController.h"

#define kSimplicityServiceName          @"com.simplicity.mail.service"

#define kServerTypeIMAP                 @"IMAP"
#define kServerTypeSMTP                 @"SMTP"

// General properties
#define kCurrentAccount                 @"CurrentAccount"
#define kAccountsCount                  @"AccountsCount"
#define kShouldShowContactImages        @"ShouldShowContactImages"
#define kShouldUseServerContactImages   @"ShouldUseServerContactImages"
#define kShouldAllowLowQualityContactImages @"ShouldAllowLowQualityContactImages"
#define kShouldShowEmailAddressesInMailboxes @"ShouldShowEmailAddressesInMailboxes"
#define kMessageListPreviewLineCount    @"MessageListPreviewLineCount"
#define kMessageCheckPeriodSec          @"MessageCheckPeriodSec"
#define kDownloadsFolder                @"DownloadsFolder"
#define kLocalStorageSizeMb             @"LocalStorageSizeMb"
#define kDefaultReplyAction             @"DefaultReplyAction"
#define kMailboxTheme                   @"MailboxTheme"
#define kShouldShowNotifications        @"ShouldShowNotifications"
#define kShouldUseSingleSignature       @"ShouldUseSingleSignature"
#define kSingleSignature                @"SingleSignature"
#define kLogLevel                       @"LogLevel"
#define kMailTransportLogLevel          @"MailTransportLogLevel"
#define kPreferableMessageFormat        @"PreferableMessageFormat"
#define kRegularMessageFont             @"RegularMessageFont"
#define kRegularMessageFontSize         @"RegularMessageFontSize"
#define kFixedMessageFont               @"FixedMessageFont"
#define kFixedMessageFontSize           @"FixedMessageFontSize"
#define kUseFixedSizeFontForPlainTextMessages @"UseFixedFontForPlainTextMessages"
#define kShouldUseUnifiedMailbox        @"ShouldUseUnifiedMailbox"

// Per-account properties
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
#define kAccountSignature               @"AccountSignature"
#define kAccountLabels                  @"AccountLabels"

@implementation SMPreferencesController {
    BOOL _shouldShowNotificationsCached;
    BOOL _shouldShowContactImagesCached;
    BOOL _shouldUseServerContactImagesCached;
    BOOL _shouldAllowLowQualityContactImagesCached;
    BOOL _shouldShowEmailAddressesInMailboxesCached;
    BOOL _shouldUseSingleSignatureCached;
    BOOL _shouldUseUnifiedMailboxCached;
    BOOL _useFixedSizeFontForPlainTextMessagesCached;
    NSUInteger _messageListPreviewLineCountCached;
    NSUInteger _messageCheckPeriodSecCached;
    NSString *_downloadsFolderCached;
    NSUInteger _localStorageSizeMbCached;
    NSString *_singleSignatureCached;
    SMMailboxTheme _mailboxThemeCached;
    NSDictionary<NSString*, SMFolderLabel*> *_labelsCached;
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

+ (BOOL)accountNameValid:(NSString*)name {
    NSCharacterSet *illegalNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    
    return (name != nil) && (name.length > 0) && ([name rangeOfCharacterFromSet:illegalNameCharacters].location == NSNotFound)? YES : NO;
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
        
        [self initLogLevel];
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
}

- (void)removeAccount:(NSInteger)accountIdx {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSUInteger accountCount = [self accountsCount];
    NSAssert(accountIdx < accountCount, @"bad accountIdx %lu, account count %lu", accountIdx, accountCount);
    
    NSError *error = nil;

    NSString *accountImageFilePath = [self accountImagePath:accountIdx];
    [[NSFileManager defaultManager] removeItemAtPath:accountImageFilePath error:&error];
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Could not remove '%@', error '%@'", accountImageFilePath, error);
    }

    NSString *accountDatabaseFilePath = [self databaseFilePath:accountIdx];
    [[NSFileManager defaultManager] removeItemAtPath:accountDatabaseFilePath error:&error];
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Could not remove '%@', error '%@'", accountDatabaseFilePath, error);
    }

    NSString *cacheDirPath = [self cacheDirPath:accountIdx];
    if(![[NSFileManager defaultManager] removeItemAtPath:cacheDirPath error:&error]) {
        SM_LOG_ERROR(@"Could not remove cache directory '%@', error: %@", cacheDirPath, error);
    }

    NSString *accountDirPath = [self accountDirPath:accountIdx];
    if(![[NSFileManager defaultManager] removeItemAtPath:accountDirPath error:&error]) {
        SM_LOG_ERROR(@"Could not remove account directory '%@', error: %@", accountDirPath, error);
    }

    [self removePassword:accountIdx serverType:kServerTypeIMAP];
    [self removePassword:accountIdx serverType:kServerTypeSMTP];

    [self removeProperty:kAccountName accountIdx:accountIdx];
    [self removeProperty:kFullUserName accountIdx:accountIdx];
    [self removeProperty:kUserEmail accountIdx:accountIdx];
    [self removeProperty:kImapServer accountIdx:accountIdx];
    [self removeProperty:kImapPort accountIdx:accountIdx];
    [self removeProperty:kImapUserName accountIdx:accountIdx];
    [self removeProperty:kImapConnectionType accountIdx:accountIdx];
    [self removeProperty:kImapAuthType accountIdx:accountIdx];
    [self removeProperty:kImapNeedCheckCertificate accountIdx:accountIdx];
    [self removeProperty:kSmtpServer accountIdx:accountIdx];
    [self removeProperty:kSmtpPort accountIdx:accountIdx];
    [self removeProperty:kSmtpUserName accountIdx:accountIdx];
    [self removeProperty:kSmtpConnectionType accountIdx:accountIdx];
    [self removeProperty:kSmtpAuthType accountIdx:accountIdx];
    [self removeProperty:kSmtpNeedCheckCertificate accountIdx:accountIdx];
    [self removeProperty:kAccountSignature accountIdx:accountIdx];
    
    [[NSUserDefaults standardUserDefaults] setInteger:(accountCount - 1) forKey:kAccountsCount];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)renameAccount:(NSInteger)accountIdx newName:(NSString*)newName {
    NSString *accountDirPath = [self accountDirPath:accountIdx];
    NSString *newAccountDirPath = [[accountDirPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];

    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtPath:accountDirPath toPath:newAccountDirPath error:&error];
    
    if(error && error.code != noErr) {
        SM_LOG_ERROR(@"Could not rename account '%@' to '%@': %@", [self accountName:accountIdx], newName, error.localizedDescription);
        return FALSE;
    }
    
    NSString *imapPassword = [self imapPassword:accountIdx];
    NSString *smtpPassword = [self smtpPassword:accountIdx];
    
    [self removePassword:accountIdx serverType:kServerTypeIMAP];
    [self removePassword:accountIdx serverType:kServerTypeSMTP];
    
    [self setAccountName:accountIdx name:newName];
    
    [self setImapPassword:accountIdx password:imapPassword];
    [self setSmtpPassword:accountIdx password:smtpPassword];

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

- (void)setProperty:(NSString*)propertyName accountIdx:(NSInteger)accountIdx obj:(NSObject*)obj {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
    if(newArr.count <= accountIdx) {
        while(newArr.count <= accountIdx) {
            [newArr addObject:obj];
        }
    }
    else {
        newArr[accountIdx] = obj;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:newArr forKey:propertyName];
}

- (void)removeProperty:(NSString*)propertyName accountIdx:(NSInteger)accountIdx {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    if(accountIdx < arr.count) {
        NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
        [newArr removeObjectAtIndex:accountIdx];
    
        [[NSUserDefaults standardUserDefaults] setObject:newArr forKey:propertyName];
    }
    else {
        SM_LOG_ERROR(@"Could not remove property %@ for accountIdx %lu", propertyName, accountIdx);
    }
}

- (NSObject*)loadProperty:(NSString*)propertyName accountIdx:(NSInteger)accountIdx {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:propertyName];
    
    if(arr != nil && accountIdx < arr.count) {
        return arr[accountIdx];
    }
    else {
        SM_LOG_ERROR(@"Could not load property %@ for accountIdx %lu", propertyName, accountIdx);
        return nil;
    }
}

#pragma mark Property setters

- (void)setAccountName:(NSInteger)accountIdx name:(NSString*)name {
    [self setProperty:kAccountName accountIdx:accountIdx obj:name];
}

- (void)setFullUserName:(NSInteger)accountIdx userName:(NSString*)fullUserName {
    [self setProperty:kFullUserName accountIdx:accountIdx obj:fullUserName];
}

- (void)setUserEmail:(NSInteger)accountIdx email:(NSString*)userEmail {
    [self setProperty:kUserEmail accountIdx:accountIdx obj:userEmail];
}

- (void)setLabels:(NSInteger)accountIdx labels:(NSDictionary<NSString*, SMFolderLabel*>*)labels {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:labels];
    [self setProperty:kAccountLabels accountIdx:accountIdx obj:data];
    
    _labelsCached = labels;
}

- (void)setImapServer:(NSInteger)accountIdx server:(NSString*)server {
    [self setProperty:kImapServer accountIdx:accountIdx obj:server];
}

- (void)setImapPort:(NSInteger)accountIdx port:(unsigned int)port {
    [self setProperty:kImapPort accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInt:port]];
}

- (void)setImapUserName:(NSInteger)accountIdx userName:(NSString*)userName {
    [self setProperty:kImapUserName accountIdx:accountIdx obj:userName];
}

- (void)setImapConnectionType:(NSInteger)accountIdx connectionType:(SMServerConnectionType)connectionType {
    [self setProperty:kImapConnectionType accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:connectionType]];
}

- (void)setImapAuthType:(NSInteger)accountIdx authType:(SMServerAuthType)authType {
    [self setProperty:kImapAuthType accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:authType]];
}

- (void)setImapNeedCheckCertificate:(NSInteger)accountIdx checkCertificate:(BOOL)checkCertificate {
    [self setProperty:kImapNeedCheckCertificate accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:checkCertificate]];
}

- (void)setSmtpServer:(NSInteger)accountIdx server:(NSString*)server {
    [self setProperty:kSmtpServer accountIdx:accountIdx obj:server];
}

- (void)setSmtpPort:(NSInteger)accountIdx port:(unsigned int)port {
    [self setProperty:kSmtpPort accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInt:port]];
}

- (void)setSmtpUserName:(NSInteger)accountIdx userName:(NSString*)userName {
    [self setProperty:kSmtpUserName accountIdx:accountIdx obj:userName];
}

- (void)setSmtpConnectionType:(NSInteger)accountIdx connectionType:(SMServerConnectionType)connectionType {
    [self setProperty:kSmtpConnectionType accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:connectionType]];
}

- (void)setSmtpAuthType:(NSInteger)accountIdx authType:(SMServerAuthType)authType {
    [self setProperty:kSmtpAuthType accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:authType]];
}

- (void)setSmtpNeedCheckCertificate:(NSInteger)accountIdx checkCertificate:(BOOL)checkCertificate {
    [self setProperty:kSmtpNeedCheckCertificate accountIdx:accountIdx obj:[NSNumber numberWithUnsignedInteger:checkCertificate]];
}

#pragma mark Property getters

- (NSString*)accountName:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kAccountName accountIdx:accountIdx];
    return str? str : @"";
}

- (NSString*)fullUserName:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kFullUserName accountIdx:accountIdx];
    return str? str : @"";
}

- (NSString*)userEmail:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kUserEmail accountIdx:accountIdx];
    return str? str : @"";
}

- (NSDictionary<NSString*, SMFolderLabel*>*)labels:(NSInteger)accountIdx {
    if(_labelsCached != nil) {
        return _labelsCached;
    }
    
    NSData *data = (NSData*)[self loadProperty:kAccountLabels accountIdx:accountIdx];
    return data? [NSKeyedUnarchiver unarchiveObjectWithData:data] : [NSDictionary dictionary];
}

- (NSURL*)accountDirURL:(NSInteger)accountIdx {
    NSURL* appDataDir = [SMAppDelegate appDataDir];
    NSAssert(appDataDir, @"no app data dir");
    
    NSString *accountName = [self accountName:accountIdx];
    NSAssert(accountName != nil && accountName.length > 0, @"bad account name");
    
    return [appDataDir URLByAppendingPathComponent:accountName isDirectory:YES];
}

- (NSString*)accountDirPath:(NSInteger)accountIdx {
    return [[self accountDirURL:accountIdx] path];
}

- (NSString*)accountImagePath:(NSInteger)accountIdx {
    NSURL *accountUrl = [self accountDirURL:accountIdx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Image.png"] isDirectory:NO];
    NSAssert(url, @"no image url");
    
    return [url path];
}

- (NSString*)databaseFilePath:(NSInteger)accountIdx {
    NSURL *accountUrl = [self accountDirURL:accountIdx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Database.sqlite"] isDirectory:NO];
    NSAssert(url, @"no data url");
    
    return [url path];
}

- (NSString*)cacheDirPath:(NSInteger)accountIdx {
    NSURL *accountUrl = [self accountDirURL:accountIdx];
    NSURL *url = [accountUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"Cache"] isDirectory:YES];
    NSAssert(url, @"no data url");
    
    return [url path];
}

- (NSString*)imapServer:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kImapServer accountIdx:accountIdx];
    return str? str : @"";
}

- (unsigned int)imapPort:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapPort accountIdx:accountIdx];
    return number? [number unsignedIntValue] : 0;
}

- (NSString*)imapUserName:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kImapUserName accountIdx:accountIdx];
    return str? str : @"";
}

- (SMServerConnectionType)imapConnectionType:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapConnectionType accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

- (SMServerAuthType)imapAuthType:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapAuthType accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

- (BOOL)imapNeedCheckCertificate:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kImapNeedCheckCertificate accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

- (NSString*)smtpServer:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kSmtpServer accountIdx:accountIdx];
    return str? str : @"";
}

- (unsigned int)smtpPort:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpPort accountIdx:accountIdx];
    return number? [number unsignedIntValue] : 0;
}

- (NSString*)smtpUserName:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kSmtpUserName accountIdx:accountIdx];
    return str? str : @"";
}

- (SMServerConnectionType)smtpConnectionType:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpConnectionType accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

- (SMServerAuthType)smtpAuthType:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpAuthType accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

- (BOOL)smtpNeedCheckCertificate:(NSInteger)accountIdx {
    NSNumber *number = (NSNumber*)[self loadProperty:kSmtpNeedCheckCertificate accountIdx:accountIdx];
    return number? [number unsignedIntegerValue] : 0;
}

#pragma mark Signature

- (void)setAccountSignature:(NSInteger)accountIdx signature:(NSString*)signature {
    [self setProperty:kAccountSignature accountIdx:accountIdx obj:signature];
}

- (NSString*)accountSignature:(NSInteger)accountIdx {
    NSString *str = (NSString*)[self loadProperty:kAccountSignature accountIdx:accountIdx];
    return str? str : @"";
}

#pragma mark Password management

- (void)setImapPassword:(NSInteger)accountIdx password:(NSString*)password {
    [self savePassword:accountIdx serverType:kServerTypeIMAP password:password];
}

- (void)setSmtpPassword:(NSInteger)accountIdx password:(NSString*)password {
    [self savePassword:accountIdx serverType:kServerTypeSMTP password:password];
}

- (NSString*)imapPassword:(NSInteger)accountIdx {
    NSString *str = [self loadPassword:accountIdx serverType:kServerTypeIMAP];
    return str? str : @"";
}

- (NSString*)smtpPassword:(NSInteger)accountIdx {
    NSString *str = [self loadPassword:accountIdx serverType:kServerTypeSMTP];
    return str? str : @"";
}

#pragma mark Secured data accessors

- (void)savePassword:(NSInteger)accountIdx serverType:(NSString*)serverType password:(NSString*)password {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSString *accountName = [self accountName:accountIdx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    [SSKeychain setPassword:password forService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Cannot save password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
    }
}

- (NSString*)loadPassword:(NSInteger)accountIdx serverType:(NSString*)serverType {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSString *accountName = [self accountName:accountIdx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if((error != nil && error.code != noErr) || password == nil) {
        SM_LOG_ERROR(@"Cannot load password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
        return @"";
    }
    
    return password;
}

- (void)removePassword:(NSInteger)accountIdx serverType:(NSString*)serverType {
    NSAssert(accountIdx >= 0, @"bad account accountIdx");
    
    NSString *accountName = [self accountName:accountIdx];
    NSString *serviceAccount = [NSString stringWithFormat:@"%@ (%@)", accountName, serverType];
    
    NSError *error = nil;
    [SSKeychain deletePasswordForService:kSimplicityServiceName account:serviceAccount error:&error];
    
    if(error != nil && error.code != noErr) {
        SM_LOG_ERROR(@"Cannot delete password for %@ account '%@', error '%@' (code %ld)", serverType, accountName, error, error? error.code : noErr);
    }
}

#pragma mark Use fixed size font for plain text messages

- (BOOL)useFixedSizeFontForPlainTextMessages {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kUseFixedSizeFontForPlainTextMessages] == nil) {
            _useFixedSizeFontForPlainTextMessagesCached = YES;
            
            SM_LOG_INFO(@"Using default kUseFixedSizeFontForPlainTextMessages: %@", _useFixedSizeFontForPlainTextMessagesCached? @"YES" : @"NO");
        }
        else {
            _useFixedSizeFontForPlainTextMessagesCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kUseFixedSizeFontForPlainTextMessages]);
            
            SM_LOG_INFO(@"Loaded kUseFixedSizeFontForPlainTextMessages: %@", _useFixedSizeFontForPlainTextMessagesCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _useFixedSizeFontForPlainTextMessagesCached;
}

- (void)setUseFixedSizeFontForPlainTextMessages:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:kUseFixedSizeFontForPlainTextMessages];
    
    _useFixedSizeFontForPlainTextMessagesCached = flag;
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

#pragma mark Should use sender's server image in message list

- (BOOL)shouldUseServerContactImages {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldUseServerContactImages] == nil) {
            _shouldUseServerContactImagesCached = YES;
            
            SM_LOG_INFO(@"Using default kShouldUseServerContactImages: %@", _shouldUseServerContactImagesCached? @"YES" : @"NO");
        }
        else {
            _shouldUseServerContactImagesCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldUseServerContactImages]);
            
            SM_LOG_INFO(@"Loaded kShouldUseServerContactImages: %@", _shouldUseServerContactImagesCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldUseServerContactImagesCached;
}

- (void)setShouldUseContactImages:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:kShouldUseServerContactImages];
    
    _shouldUseServerContactImagesCached = flag;
}

#pragma mark Should allow low-res images in message list

- (BOOL)shouldAllowLowQualityContactImages {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldAllowLowQualityContactImages] == nil) {
            _shouldAllowLowQualityContactImagesCached = NO;
            
            SM_LOG_INFO(@"Using default kShouldAllowLowQualityContactImages: %@", _shouldAllowLowQualityContactImagesCached? @"YES" : @"NO");
        }
        else {
            _shouldAllowLowQualityContactImagesCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldAllowLowQualityContactImages]);
            
            SM_LOG_INFO(@"Loaded kShouldAllowLowQualityContactImages: %@", _shouldAllowLowQualityContactImagesCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldAllowLowQualityContactImagesCached;
}

- (void)setAllowLowQualityContactImages:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:kShouldAllowLowQualityContactImages];
    
    _shouldAllowLowQualityContactImagesCached = flag;
}

#pragma mark Should show email addresses in mailboxes

- (BOOL)shouldShowEmailAddressesInMailboxes {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldShowEmailAddressesInMailboxes] == nil) {
            _shouldShowEmailAddressesInMailboxesCached = NO;
            
            SM_LOG_INFO(@"Using default kShouldShowEmailAddressesInMailboxes: %@", _shouldShowEmailAddressesInMailboxesCached? @"YES" : @"NO");
        }
        else {
            _shouldShowEmailAddressesInMailboxesCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldShowEmailAddressesInMailboxes]);
            
            SM_LOG_INFO(@"Loaded kShouldShowEmailAddressesInMailboxes: %@", _shouldShowEmailAddressesInMailboxesCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldShowEmailAddressesInMailboxesCached;
}

- (void)setShouldShowEmailAddressesInMailboxes:(BOOL)flag {
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:kShouldShowEmailAddressesInMailboxes];
    
    _shouldShowEmailAddressesInMailboxesCached = flag;
}

#pragma mark Should show notifications

- (BOOL)shouldShowNotifications {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldShowNotifications] == nil) {
            _shouldShowNotificationsCached = YES;
            
            SM_LOG_INFO(@"Using default kShouldShowNotifications: %@", _shouldShowNotificationsCached? @"YES" : @"NO");
        }
        else {
            _shouldShowNotificationsCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldShowNotifications]);
            
            SM_LOG_INFO(@"Loaded kShouldShowNotifications: %@", _shouldShowNotificationsCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldShowNotificationsCached;
}

- (void)setShouldShowNotifications:(BOOL)shouldShowNotifications {
    [[NSUserDefaults standardUserDefaults] setBool:shouldShowNotifications forKey:kShouldShowNotifications];
    
    _shouldShowNotificationsCached = shouldShowNotifications;
}

#pragma mark Current Account

- (NSInteger)currentAccount {
    if([[NSUserDefaults standardUserDefaults] objectForKey:kCurrentAccount] == nil) {
        return 0;
    }
    else {
        return [[NSUserDefaults standardUserDefaults] integerForKey:kCurrentAccount];
    }
}

- (void)setCurrentAccount:(NSInteger)accountIdx {
    [[NSUserDefaults standardUserDefaults] setInteger:accountIdx forKey:kCurrentAccount];
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

#pragma mark Local storage size

- (NSUInteger)localStorageSizeMb {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kLocalStorageSizeMb] == nil) {
            _localStorageSizeMbCached = 0;
            
            SM_LOG_INFO(@"Using default _localStorageSizeMbCached: %lu", _localStorageSizeMbCached);
        }
        else {
            _localStorageSizeMbCached = [[NSUserDefaults standardUserDefaults] integerForKey:kLocalStorageSizeMb];
            
            SM_LOG_INFO(@"Loaded _localStorageSizeMbCached: %lu", _localStorageSizeMbCached);
        }
        
        skipUserDefaults = YES;
    }
    
    return _localStorageSizeMbCached;
}

- (void)setLocalStorageSizeMb:(NSUInteger)sizeMb {
    [[NSUserDefaults standardUserDefaults] setInteger:sizeMb forKey:kLocalStorageSizeMb];
    
    _localStorageSizeMbCached = sizeMb;
}

#pragma mark Default reply action

- (SMDefaultReplyAction)defaultReplyAction {
    SMDefaultReplyAction result = SMDefaultReplyAction_ReplyAll;
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:kDefaultReplyAction] == nil) {
        SM_LOG_INFO(@"Value for %@ not found, using defaults", kDefaultReplyAction);
    }
    else {
        NSUInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kDefaultReplyAction];

        if(value != SMDefaultReplyAction_ReplyAll && value != SMDefaultReplyAction_Reply) {
            SM_LOG_INFO(@"Value %lu for %@ is invalid, using defaults", value, kDefaultReplyAction);
        }
        else {
            result = value;
        }
    }
    
    return result;
}

- (void)setDefaultReplyAction:(SMDefaultReplyAction)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:kDefaultReplyAction];
}

#pragma mark Mailbox theme

- (SMMailboxTheme)mailboxTheme {
    static BOOL skipUserDefaults = NO;

    if(!skipUserDefaults) {
        SMMailboxTheme result = SMMailboxTheme_Dark;
        
        if([[NSUserDefaults standardUserDefaults] objectForKey:kMailboxTheme] == nil) {
            SM_LOG_INFO(@"Value for %@ not found, using defaults", kMailboxTheme);
        }
        else {
            NSUInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kMailboxTheme];
            
            if(value != SMMailboxTheme_Light && value != SMMailboxTheme_MediumLight && value != SMMailboxTheme_MediumDark && value != SMMailboxTheme_Dark) {
                SM_LOG_INFO(@"Value %lu for %@ is invalid, using defaults", value, kMailboxTheme);
            }
            else {
                result = value;
            }
        }
    
        skipUserDefaults = YES;
        
        _mailboxThemeCached = result;
    }

    return _mailboxThemeCached;
}

- (void)setMailboxTheme:(SMMailboxTheme)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:kMailboxTheme];

    _mailboxThemeCached = value;
}

#pragma mark Signatures

- (BOOL)shouldUseSingleSignature {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldUseSingleSignature] == nil) {
            _shouldUseSingleSignatureCached = YES;
            
            SM_LOG_INFO(@"Using default kShouldUseSingleSignature: %@", _shouldUseSingleSignatureCached? @"YES" : @"NO");
        }
        else {
            _shouldUseSingleSignatureCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldUseSingleSignature]);
            
            SM_LOG_INFO(@"Loaded kShouldUseSingleSignature: %@", _shouldUseSingleSignatureCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldUseSingleSignatureCached;
}

- (void)setShouldUseSingleSignature:(BOOL)shouldUseSingleSignature {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseSingleSignature forKey:kShouldUseSingleSignature];
    
    _shouldUseSingleSignatureCached = shouldUseSingleSignature;
}

- (NSString*)singleSignature {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        _singleSignatureCached = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:kSingleSignature];
        
        skipUserDefaults = YES;
    }
    
    return _singleSignatureCached;
}

- (void)setSingleSignature:(NSString*)signatureHtml {
    [[NSUserDefaults standardUserDefaults] setObject:signatureHtml forKey:kSingleSignature];
    
    _singleSignatureCached = signatureHtml;
}

#pragma mark Log level

- (void)initLogLevel {
    [self logLevel];
    [self mailTransportLogLevel];
}

- (NSUInteger)mailTransportLogLevel {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kMailTransportLogLevel] == nil) {
            MCLogEnabled = 0;
            
            SM_LOG_INFO(@"Using default MCLogEnabled: %d", MCLogEnabled);
        }
        else {
            MCLogEnabled = (int)[[NSUserDefaults standardUserDefaults] integerForKey:kMailTransportLogLevel];
            
            SM_LOG_INFO(@"Loaded MCLogEnabled: %d", MCLogEnabled);
        }
        
        skipUserDefaults = YES;
    }
    
    return MCLogEnabled;
}

- (void)setMailTransportLogLevel:(NSUInteger)logLevel {
    [[NSUserDefaults standardUserDefaults] setInteger:logLevel forKey:kMailTransportLogLevel];
    
    MCLogEnabled = (int)logLevel;
}

- (NSUInteger)logLevel {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kLogLevel] == nil) {
            SMLogLevel = SM_LOG_LEVEL_INFO;
            
            SM_LOG_INFO(@"Using default SMLogLevel: %lu", SMLogLevel);
        }
        else {
            SMLogLevel = [[NSUserDefaults standardUserDefaults] integerForKey:kLogLevel];
            
            SM_LOG_INFO(@"Loaded SMLogLevel: %lu", SMLogLevel);
        }
        
        skipUserDefaults = YES;
    }
    
    return SMLogLevel;
}

- (void)setLogLevel:(NSUInteger)logLevel {
    [[NSUserDefaults standardUserDefaults] setInteger:logLevel forKey:kLogLevel];
    
    SMLogLevel = logLevel;
}

#pragma mark Preferable message format

- (SMPreferableMessageFormat)preferableMessageFormat {
    SMPreferableMessageFormat result = SMPreferableMessageFormat_HTML;
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:kPreferableMessageFormat] == nil) {
        SM_LOG_INFO(@"Value for %@ not found, using defaults", kPreferableMessageFormat);
    }
    else {
        NSUInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kPreferableMessageFormat];
        
        if(value != SMPreferableMessageFormat_HTML && value != SMPreferableMessageFormat_RawText) {
            SM_LOG_INFO(@"Value %lu for %@ is invalid, using defaults", value, kPreferableMessageFormat);
        }
        else {
            result = value;
        }
    }
    
    return result;
}

- (void)setPreferableMessageFormat:(SMPreferableMessageFormat)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:kPreferableMessageFormat];
}

#pragma mark Regular message font

- (NSFont*)regularMessageFont {
    NSData *fontDescData = [[NSUserDefaults standardUserDefaults] objectForKey:kRegularMessageFont];
    if(fontDescData != nil) {
        NSFontDescriptor *fontDesc = [NSKeyedUnarchiver unarchiveObjectWithData:fontDescData];

        CGFloat fontSize = 11;
        if([[NSUserDefaults standardUserDefaults] objectForKey:kRegularMessageFontSize] != nil) {
            fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:kRegularMessageFontSize];
        }
        else {
            SM_LOG_INFO(@"Value for %@ not found, using defaults", kRegularMessageFontSize);
        }
        
        return [NSFont fontWithDescriptor:fontDesc size:fontSize];
    }
    else {
        SM_LOG_INFO(@"Value for %@ not found, using defaults", kRegularMessageFont);
        
        return [NSFont fontWithName:@"Helvetica" size:11];
    }
}

- (void)setRegularMessageFont:(NSFont*)font  {
    NSFontDescriptor *fontDesc = font.fontDescriptor;
    NSData *fontDescData = [NSKeyedArchiver archivedDataWithRootObject:fontDesc];
    [[NSUserDefaults standardUserDefaults] setObject:fontDescData forKey:kRegularMessageFont];
    [[NSUserDefaults standardUserDefaults] setFloat:font.pointSize forKey:kRegularMessageFontSize];
}

#pragma mark Fixed message font

- (NSFont*)fixedMessageFont {
    NSData *fontDescData = [[NSUserDefaults standardUserDefaults] objectForKey:kFixedMessageFont];
    if(fontDescData != nil) {
        NSFontDescriptor *fontDesc = [NSKeyedUnarchiver unarchiveObjectWithData:fontDescData];
        
        CGFloat fontSize = 11;
        if([[NSUserDefaults standardUserDefaults] objectForKey:kFixedMessageFontSize] != nil) {
            fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:kFixedMessageFontSize];
        }
        else {
            SM_LOG_INFO(@"Value for %@ not found, using defaults", kFixedMessageFontSize);
        }
        
        return [NSFont fontWithDescriptor:fontDesc size:fontSize];
    }
    else {
        SM_LOG_INFO(@"Value for %@ not found, using defaults", kFixedMessageFont);
        
        return [NSFont fontWithName:@"Menlo" size:11];
    }
}

- (void)setFixedMessageFont:(NSFont*)font  {
    NSFontDescriptor *fontDesc = font.fontDescriptor;
    NSData *fontDescData = [NSKeyedArchiver archivedDataWithRootObject:fontDesc];
    [[NSUserDefaults standardUserDefaults] setObject:fontDescData forKey:kFixedMessageFont];
    [[NSUserDefaults standardUserDefaults] setFloat:font.pointSize forKey:kFixedMessageFontSize];
}

#pragma mark Unified Mailbox

- (BOOL)shouldUseUnifiedMailbox {
    static BOOL skipUserDefaults = NO;
    
    if(!skipUserDefaults) {
        if([[NSUserDefaults standardUserDefaults] objectForKey:kShouldUseUnifiedMailbox] == nil) {
            _shouldUseUnifiedMailboxCached = YES;
            
            SM_LOG_INFO(@"Using default kShouldUseUnifiedMailbox: %@", _shouldUseUnifiedMailboxCached? @"YES" : @"NO");
        }
        else {
            _shouldUseUnifiedMailboxCached = ([[NSUserDefaults standardUserDefaults] boolForKey:kShouldUseUnifiedMailbox]);
            
            SM_LOG_INFO(@"Loaded kShouldUseUnifiedMailbox: %@", _shouldUseUnifiedMailboxCached? @"YES" : @"NO");
        }
        
        skipUserDefaults = YES;
    }
    
    return _shouldUseUnifiedMailboxCached;
}

- (void)setShouldUseUnifiedMailbox:(BOOL)shouldUseUnifiedMailbox {
    [[NSUserDefaults standardUserDefaults] setBool:shouldUseUnifiedMailbox forKey:kShouldUseUnifiedMailbox];
    
    _shouldUseUnifiedMailboxCached = shouldUseUnifiedMailbox;
}
@end
