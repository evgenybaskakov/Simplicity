//
//  SMAbstractAccount.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/2/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessageListController;
@class SMSearchResultsListController;
@class SMAccountMailboxController;
@class SMOutboxController;
@class SMAccountMailbox;
@class SMMessageListController;
@class SMSearchResultsListController;
@class SMAccountMailboxController;
@class SMOutboxController;
@class SMAccountMailbox;
@class SMLocalFolderRegistry;
@class SMDatabase;

@protocol SMAbstractAccount

@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMSearchResultsListController *searchResultsListController;
@property (readonly) SMAccountMailboxController *mailboxController;
@property (readonly) SMOutboxController *outboxController;
@property (readonly) SMAccountMailbox *mailbox;
@property (readonly) SMDatabase *database;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;

@end
