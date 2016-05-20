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

- (void)addAccountWithName:(NSString*)accountName image:(NSImage*)image userName:(NSString*)userName emailAddress:(NSString*)emailAddress provider:(SMMailServiceProvider*)provider;
- (void)removeAccount:(NSUInteger)accountIdx;
- (BOOL)renameAccount:(NSUInteger)accountIdx newName:(NSString*)newName;
- (BOOL)accountExists:(NSString*)accountName;

- (void)setAccountName:(NSUInteger)accountIdx name:(NSString*)name;
- (void)setFullUserName:(NSUInteger)accountIdx userName:(NSString*)fullUserName;
- (void)setUserEmail:(NSUInteger)accountIdx email:(NSString*)userEmail;
- (void)setLabels:(NSUInteger)accountIdx labels:(NSDictionary<NSString*, SMFolderLabel*>*)labels;

- (void)setImapServer:(NSUInteger)accountIdx server:(NSString*)server;
- (void)setImapPort:(NSUInteger)accountIdx port:(unsigned int)port;
- (void)setImapUserName:(NSUInteger)accountIdx userName:(NSString*)userName;
- (void)setImapPassword:(NSUInteger)accountIdx password:(NSString*)password;
- (void)setImapConnectionType:(NSUInteger)accountIdx connectionType:(SMServerConnectionType)connectionType;
- (void)setImapAuthType:(NSUInteger)accountIdx authType:(SMServerAuthType)authType;
- (void)setImapNeedCheckCertificate:(NSUInteger)accountIdx checkCertificate:(BOOL)checkCertificate;

- (void)setSmtpServer:(NSUInteger)accountIdx server:(NSString*)server;
- (void)setSmtpPort:(NSUInteger)accountIdx port:(unsigned int)port;
- (void)setSmtpUserName:(NSUInteger)accountIdx userName:(NSString*)userName;
- (void)setSmtpPassword:(NSUInteger)accountIdx password:(NSString*)password;
- (void)setSmtpConnectionType:(NSUInteger)accountIdx connectionType:(SMServerConnectionType)connectionType;
- (void)setSmtpAuthType:(NSUInteger)accountIdx authType:(SMServerAuthType)authType;
- (void)setSmtpNeedCheckCertificate:(NSUInteger)accountIdx checkCertificate:(BOOL)checkCertificate;

- (NSString*)accountName:(NSUInteger)accountIdx;
- (NSString*)fullUserName:(NSUInteger)accountIdx;
- (NSString*)userEmail:(NSUInteger)accountIdx;
- (NSString*)accountImagePath:(NSUInteger)accountIdx;
- (NSString*)databaseFilePath:(NSUInteger)accountIdx;
- (NSString*)cacheDirPath:(NSUInteger)accountIdx;
- (NSDictionary<NSString*, SMFolderLabel*>*)labels:(NSUInteger)accountIdx;

- (void)setAccountSignature:(NSUInteger)accountIdx signature:(NSString*)signature;
- (NSString*)accountSignature:(NSUInteger)accountIdx;

- (NSString*)imapServer:(NSUInteger)accountIdx;
- (unsigned int)imapPort:(NSUInteger)accountIdx;
- (NSString*)imapUserName:(NSUInteger)accountIdx;
- (NSString*)imapPassword:(NSUInteger)accountIdx;
- (SMServerConnectionType)imapConnectionType:(NSUInteger)accountIdx;
- (SMServerAuthType)imapAuthType:(NSUInteger)accountIdx;
- (BOOL)imapNeedCheckCertificate:(NSUInteger)accountIdx;

- (NSString*)smtpServer:(NSUInteger)accountIdx;
- (unsigned int)smtpPort:(NSUInteger)accountIdx;
- (NSString*)smtpUserName:(NSUInteger)accountIdx;
- (NSString*)smtpPassword:(NSUInteger)accountIdx;
- (SMServerConnectionType)smtpConnectionType:(NSUInteger)accountIdx;
- (SMServerAuthType)smtpAuthType:(NSUInteger)accountIdx;
- (BOOL)smtpNeedCheckCertificate:(NSUInteger)accountIdx;

@end
