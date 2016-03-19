//
//  SMSimplicityContainer.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@class SMPreferencesController;
@class SMUserAccount;
@class SMDatabase;
@class SMMailbox;
@class SMLocalFolderRegistry;
@class SMMessageListController;
@class SMSearchResultsListController;
@class SMMailboxController;
@class SMOutboxController;
@class SMOperationExecutor;
@class SMMessage;

@class MCOIMAPSession;
@class MCOSMTPSession;

@interface SMSimplicityContainer : NSObject

@property MCOIMAPSession *imapSession;
@property MCOSMTPSession *smtpSession;

@property (readonly) SMUserAccount *account;
@property (readonly) SMDatabase *database;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;
@property (readonly) MCOIndexSet *imapServerCapabilities;
@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMSearchResultsListController *searchResultsListController;
@property (readonly) SMMailboxController *mailboxController;
@property (readonly) SMOutboxController *outboxController;
@property (readonly) SMMailbox *mailbox;
@property (readonly) SMOperationExecutor *operationExecutor;

- (id)initWithAccount:(SMUserAccount*)account preferencesController:(SMPreferencesController*)preferencesController;

- (void)initSession;
- (void)initOpExecutor;
- (void)getIMAPServerCapabilities;
- (void)fetchMessageInlineAttachments:(SMMessage*)message;

@end
