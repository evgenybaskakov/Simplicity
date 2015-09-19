//
//  SMModel.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@class SMDatabase;
@class SMMailbox;
@class SMMessageStorage;
@class SMLocalFolderRegistry;
@class SMAttachmentStorage;
@class SMMessageListController;
@class SMSearchResultsListController;
@class SMMailboxController;
@class SMMessageComparators;

@class MCOIMAPSession;
@class MCOSMTPSession;

@interface SMSimplicityContainer : NSObject

@property MCOIMAPSession *imapSession;
@property MCOSMTPSession *smtpSession;

@property (readonly) SMDatabase *database;
@property (readonly) SMMessageStorage *messageStorage;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;
@property (readonly) SMAttachmentStorage *attachmentStorage;
@property (readonly) MCOIndexSet *imapServerCapabilities;
@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMSearchResultsListController *searchResultsListController;
@property (readonly) SMMailboxController *mailboxController;
@property (readonly) SMMailbox *mailbox;
@property (readonly) SMMessageComparators *messageComparators;

@end
