//
//  SMAbstractAccount.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/2/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SMMailbox;
@protocol SMMailboxController;

@class SMMessageListController;
@class SMSearchResultsListController;
@class SMOutboxController;
@class SMLocalFolderRegistry;
@class SMDatabase;
@class SMMessage;

@protocol SMAbstractAccount

@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMSearchResultsListController *searchResultsListController;
@property (readonly) SMOutboxController *outboxController;
@property (readonly) SMDatabase *database;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;

@property (readonly) id<SMMailbox> mailbox;
@property (readonly) id<SMMailboxController> mailboxController;

- (void)fetchMessageInlineAttachments:(SMMessage*)message;

@end
