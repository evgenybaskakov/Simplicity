//
//  SMUnifiedAccount.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/2/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMailbox.h"
#import "SMUnifiedMailboxController.h"
#import "SMUnifiedSearchController.h"
#import "SMFolderColorController.h"
#import "SMLocalFolderRegistry.h"
#import "SMAccountSearchController.h"
#import "SMMessageListController.h"
#import "SMOutboxController.h"

@implementation SMUnifiedAccount

@synthesize folderColorController = _folderColorController;
@synthesize messageListController = _messageListController;
@synthesize searchController = _searchController;
@synthesize mailboxController = _mailboxController;
@synthesize outboxController = _outboxController;
@synthesize mailbox = _mailbox;
@synthesize localFolderRegistry = _localFolderRegistry;
@synthesize foldersInitialized = _foldersInitialized;
@synthesize accountAddress = _accountAddress;
@synthesize accountImage = _accountImage;
@synthesize accountName = _accountName;

- (id)init {
    self = [super init];
    
    if(self) {
        _mailbox = [[SMUnifiedMailbox alloc] init];
        _folderColorController = [[SMFolderColorController alloc] initWithUserAccount:self];
        _localFolderRegistry = [[SMLocalFolderRegistry alloc] initWithUserAccount:self];
        _messageListController = [[SMMessageListController alloc] initWithUserAccount:self];
        _searchController = [[SMUnifiedSearchController alloc] initWithUserAccount:self];
        _mailboxController = [[SMUnifiedMailboxController alloc] initWithUserAccount:self];
        _outboxController = [[SMOutboxController alloc] initWithUserAccount:self];
        
        [_mailboxController initFolders];
        
        SMFolder *inboxFolder = [_mailbox inboxFolder];
        NSAssert(inboxFolder, @"no inbox folder in the unified mailbox");
        
        [_messageListController changeFolder:inboxFolder.fullName clearSearch:YES];
        [_mailboxController changeFolder:inboxFolder];
    }
    
    return self;
}

- (BOOL)unified {
    return YES;
}

- (SMDatabase*)database {
    SM_FATAL(@"no database instance in the unified account");
    return nil;
}

- (void)fetchMessageInlineAttachments:(SMMessage*)message {
    SM_FATAL(@"TODO");
}

- (void)ensureMainLocalFoldersCreated {
    SM_FATAL(@"not implemented in the unified account");
}

@end
