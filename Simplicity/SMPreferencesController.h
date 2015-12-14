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

typedef NS_ENUM(NSUInteger, SMDefaultReplyAction) {
    SMDefaultReplyAction_ReplyAll,
    SMDefaultReplyAction_Reply,
};

typedef NS_ENUM(NSUInteger, SMPreferableMessageFormat) {
    SMPreferableMessageFormat_HTML,
    SMPreferableMessageFormat_RawText,
};

@interface SMPreferencesController : NSObject

@property (nonatomic) BOOL shouldShowContactImages;
@property (nonatomic) BOOL shouldShowNotifications;
@property (nonatomic) BOOL shouldUseSingleSignature;
@property (nonatomic) NSUInteger messageListPreviewLineCount;
@property (nonatomic) NSUInteger messageCheckPeriodSec;
@property (nonatomic) NSString *downloadsFolder;
@property (nonatomic) NSUInteger localStorageSizeMb;
@property (nonatomic) SMDefaultReplyAction defaultReplyAction;
@property (nonatomic) SMPreferableMessageFormat preferableMessageFormat;
@property (nonatomic) NSString *singleSignature;
@property (nonatomic) NSUInteger logLevel;

+ (SMServerConnectionType)mcoToSMConnectionType:(MCOConnectionType)mcoConnectionType;
+ (MCOConnectionType)smToMCOConnectionType:(SMServerConnectionType)smConnectionType;

+ (SMServerAuthType)mcoToSMAuthType:(MCOAuthType)mcoAuthType;
+ (MCOAuthType)smToMCOAuthType:(SMServerAuthType)smAuthType;

+ (BOOL)accountNameValid:(NSString*)name;

- (NSUInteger)accountsCount;

- (void)addAccountWithName:(NSString*)accountName image:(NSImage*)image userName:(NSString*)userName emailAddress:(NSString*)emailAddress provider:(SMMailServiceProvider*)provider;
- (void)removeAccount:(NSUInteger)idx;
- (BOOL)renameAccount:(NSUInteger)idx newName:(NSString*)newName;
- (BOOL)accountExists:(NSString*)accountName;

- (void)setAccountName:(NSUInteger)idx name:(NSString*)name;
- (void)setFullUserName:(NSUInteger)idx userName:(NSString*)fullUserName;
- (void)setUserEmail:(NSUInteger)idx email:(NSString*)userEmail;
- (void)setLabels:(NSUInteger)idx labels:(NSArray<SMFolderLabel*>*)labels;

- (void)setImapServer:(NSUInteger)idx server:(NSString*)server;
- (void)setImapPort:(NSUInteger)idx port:(unsigned int)port;
- (void)setImapUserName:(NSUInteger)idx userName:(NSString*)userName;
- (void)setImapPassword:(NSUInteger)idx password:(NSString*)password;
- (void)setImapConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType;
- (void)setImapAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType;
- (void)setImapNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate;

- (void)setSmtpServer:(NSUInteger)idx server:(NSString*)server;
- (void)setSmtpPort:(NSUInteger)idx port:(unsigned int)port;
- (void)setSmtpUserName:(NSUInteger)idx userName:(NSString*)userName;
- (void)setSmtpPassword:(NSUInteger)idx password:(NSString*)password;
- (void)setSmtpConnectionType:(NSUInteger)idx connectionType:(SMServerConnectionType)connectionType;
- (void)setSmtpAuthType:(NSUInteger)idx authType:(SMServerAuthType)authType;
- (void)setSmtpNeedCheckCertificate:(NSUInteger)idx checkCertificate:(BOOL)checkCertificate;

- (NSString*)accountName:(NSUInteger)idx;
- (NSString*)fullUserName:(NSUInteger)idx;
- (NSString*)userEmail:(NSUInteger)idx;
- (NSString*)accountImagePath:(NSUInteger)idx;
- (NSString*)databaseFilePath:(NSUInteger)idx;
- (NSString*)cacheDirPath:(NSUInteger)idx;
- (NSArray<SMFolderLabel*>*)labels:(NSUInteger)idx;

- (void)setAccountSignature:(NSUInteger)idx signature:(NSString*)signature;
- (NSString*)accountSignature:(NSUInteger)idx;

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
