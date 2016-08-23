//
//  SMPreferencesController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/31/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import <Foundation/Foundation.h>

#import "SMMailServiceProvider.h"

@class SMFolderLabel;

typedef NS_ENUM(NSUInteger, SMMailboxTheme) {
    SMMailboxTheme_Light,
    SMMailboxTheme_MediumLight,
    SMMailboxTheme_MediumDark,
    SMMailboxTheme_Dark,
};

typedef NS_ENUM(NSUInteger, SMDefaultReplyAction) {
    SMDefaultReplyAction_ReplyAll,
    SMDefaultReplyAction_Reply,
};

typedef NS_ENUM(NSUInteger, SMPreferableMessageFormat) {
    SMPreferableMessageFormat_HTML,
    SMPreferableMessageFormat_RawText,
};

@interface SMPreferencesController : NSObject

@property (nonatomic) NSInteger currentAccount;
@property (nonatomic) BOOL useFixedSizeFontForPlainTextMessages;
@property (nonatomic) BOOL shouldShowContactImages;
@property (nonatomic) BOOL shouldUseServerContactImages;
@property (nonatomic) BOOL shouldAllowLowQualityContactImages;
@property (nonatomic) BOOL shouldShowEmailAddressesInMailboxes;
@property (nonatomic) BOOL shouldShowNotifications;
@property (nonatomic) BOOL shouldUseSingleSignature;
@property (nonatomic) BOOL shouldUseUnifiedMailbox;
@property (nonatomic) NSUInteger messageListPreviewLineCount;
@property (nonatomic) NSUInteger messageCheckPeriodSec;
@property (nonatomic) NSString *downloadsFolder;
@property (nonatomic) NSUInteger localStorageSizeMb;
@property (nonatomic) SMDefaultReplyAction defaultReplyAction;
@property (nonatomic) SMMailboxTheme mailboxTheme;
@property (nonatomic) SMPreferableMessageFormat preferableMessageFormat;
@property (nonatomic) NSString *singleSignature;
@property (nonatomic) NSUInteger logLevel;
@property (nonatomic) NSUInteger mailTransportLogLevel;
@property (nonatomic) NSFont *regularMessageFont;
@property (nonatomic) NSFont *fixedMessageFont;

+ (SMServerConnectionType)mcoToSMConnectionType:(MCOConnectionType)mcoConnectionType;
+ (MCOConnectionType)smToMCOConnectionType:(SMServerConnectionType)smConnectionType;

+ (SMServerAuthType)mcoToSMAuthType:(MCOAuthType)mcoAuthType;
+ (MCOAuthType)smToMCOAuthType:(SMServerAuthType)smAuthType;

+ (BOOL)accountNameValid:(NSString*)name;

- (NSUInteger)accountsCount;
- (NSURL*)accountDirURL:(NSInteger)accountIdx;

- (void)addAccountWithName:(NSString*)accountName image:(NSImage*)image userName:(NSString*)userName emailAddress:(NSString*)emailAddress provider:(SMMailServiceProvider*)provider;
- (void)removeAccount:(NSInteger)accountIdx;
- (BOOL)renameAccount:(NSInteger)accountIdx newName:(NSString*)newName;
- (BOOL)accountExists:(NSString*)accountName;

- (void)setAccountName:(NSInteger)accountIdx name:(NSString*)name;
- (void)setFullUserName:(NSInteger)accountIdx userName:(NSString*)fullUserName;
- (void)setUserEmail:(NSInteger)accountIdx email:(NSString*)userEmail;
- (void)setLabels:(NSInteger)accountIdx labels:(NSDictionary<NSString*, SMFolderLabel*>*)labels;

- (void)setImapServer:(NSInteger)accountIdx server:(NSString*)server;
- (void)setImapPort:(NSInteger)accountIdx port:(unsigned int)port;
- (void)setImapUserName:(NSInteger)accountIdx userName:(NSString*)userName;
- (void)setImapPassword:(NSInteger)accountIdx password:(NSString*)password;
- (void)setImapConnectionType:(NSInteger)accountIdx connectionType:(SMServerConnectionType)connectionType;
- (void)setImapAuthType:(NSInteger)accountIdx authType:(SMServerAuthType)authType;
- (void)setImapNeedCheckCertificate:(NSInteger)accountIdx checkCertificate:(BOOL)checkCertificate;

- (void)setSmtpServer:(NSInteger)accountIdx server:(NSString*)server;
- (void)setSmtpPort:(NSInteger)accountIdx port:(unsigned int)port;
- (void)setSmtpUserName:(NSInteger)accountIdx userName:(NSString*)userName;
- (void)setSmtpPassword:(NSInteger)accountIdx password:(NSString*)password;
- (void)setSmtpConnectionType:(NSInteger)accountIdx connectionType:(SMServerConnectionType)connectionType;
- (void)setSmtpAuthType:(NSInteger)accountIdx authType:(SMServerAuthType)authType;
- (void)setSmtpNeedCheckCertificate:(NSInteger)accountIdx checkCertificate:(BOOL)checkCertificate;

- (NSString*)accountName:(NSInteger)accountIdx;
- (NSString*)fullUserName:(NSInteger)accountIdx;
- (NSString*)userEmail:(NSInteger)accountIdx;
- (NSString*)accountImagePath:(NSInteger)accountIdx;
- (NSString*)databaseFilePath:(NSInteger)accountIdx;
- (NSString*)cacheDirPath:(NSInteger)accountIdx;
- (NSDictionary<NSString*, SMFolderLabel*>*)labels:(NSInteger)accountIdx;

- (void)setAccountSignature:(NSInteger)accountIdx signature:(NSString*)signature;
- (NSString*)accountSignature:(NSInteger)accountIdx;

- (NSString*)imapServer:(NSInteger)accountIdx;
- (unsigned int)imapPort:(NSInteger)accountIdx;
- (NSString*)imapUserName:(NSInteger)accountIdx;
- (NSString*)imapPassword:(NSInteger)accountIdx;
- (SMServerConnectionType)imapConnectionType:(NSInteger)accountIdx;
- (SMServerAuthType)imapAuthType:(NSInteger)accountIdx;
- (BOOL)imapNeedCheckCertificate:(NSInteger)accountIdx;

- (NSString*)smtpServer:(NSInteger)accountIdx;
- (unsigned int)smtpPort:(NSInteger)accountIdx;
- (NSString*)smtpUserName:(NSInteger)accountIdx;
- (NSString*)smtpPassword:(NSInteger)accountIdx;
- (SMServerConnectionType)smtpConnectionType:(NSInteger)accountIdx;
- (SMServerAuthType)smtpAuthType:(NSInteger)accountIdx;
- (BOOL)smtpNeedCheckCertificate:(NSInteger)accountIdx;

@end
