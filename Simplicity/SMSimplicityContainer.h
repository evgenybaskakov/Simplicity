//
//  SMModel.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@class SMPreferencesController;
@class SMAccountDescriptor;
@class SMDatabase;
@class SMMailbox;
@class SMLocalFolderRegistry;
@class SMAttachmentStorage;
@class SMMessageListController;
@class SMSearchResultsListController;
@class SMMailboxController;
@class SMAddressBookController;
@class SMMessageComparators;

@class MCOIMAPSession;
@class MCOSMTPSession;

@interface SMSimplicityContainer : NSObject

@property MCOIMAPSession *imapSession;
@property MCOSMTPSession *smtpSession;

@property (readonly) SMAccountDescriptor *account;
@property (readonly) SMDatabase *database;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;
@property (readonly) SMAttachmentStorage *attachmentStorage;
@property (readonly) MCOIndexSet *imapServerCapabilities;
@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMSearchResultsListController *searchResultsListController;
@property (readonly) SMMailboxController *mailboxController;
@property (readonly) SMMailbox *mailbox;
@property (readonly) SMMessageComparators *messageComparators;
@property (readonly) SMAddressBookController *addressBookController;

- (id)initWithAccount:(SMAccountDescriptor*)account preferencesController:(SMPreferencesController*)preferencesController;

- (void)initSession;
- (void)getIMAPServerCapabilities;

@end
