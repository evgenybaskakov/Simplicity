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
@protocol SMAbstractSearchResultsController;

@class SMAttachmentStorage;
@class SMFolderColorController;
@class SMMessageListController;
@class SMSearchResultsController;
@class SMOutboxController;
@class SMLocalFolderRegistry;
@class SMDatabase;
@class SMMessage;

@protocol SMAbstractAccount

@property (readonly) BOOL unified;
@property (readonly) SMFolderColorController *folderColorController;
@property (readonly) SMMessageListController *messageListController;
@property (readonly) SMOutboxController *outboxController;
@property (readonly) SMDatabase *database;
@property (readonly) SMLocalFolderRegistry *localFolderRegistry;
@property (readonly) SMAttachmentStorage *attachmentStorage;
@property (readonly) id<SMMailbox> mailbox;
@property (readonly) id<SMMailboxController> mailboxController;
@property (readonly) id<SMAbstractSearchResultsController> searchResultsController;

@property BOOL foldersInitialized; // TODO: this is crap

- (void)fetchMessageInlineAttachments:(SMMessage*)message;

@end
