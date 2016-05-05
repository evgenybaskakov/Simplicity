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
#import "SMSearchResultsListController.h"
#import "SMMessageListController.h"
#import "SMOutboxController.h"

@implementation SMUnifiedAccount

@synthesize messageListController = _messageListController;
@synthesize searchResultsListController = _searchResultsListController;
@synthesize mailboxController = _mailboxController;
@synthesize outboxController = _outboxController;
@synthesize mailbox = _mailbox;
@synthesize localFolderRegistry = _localFolderRegistry;

- (id)init {
    self = [super init];
    
    if(self) {
        _mailbox = [[SMUnifiedMailbox alloc] init];
        _localFolderRegistry = nil; // TODO
        _messageListController = [[SMMessageListController alloc] initWithUserAccount:self];
        _searchResultsListController = [[SMSearchResultsListController alloc] initWithUserAccount:self];
        _mailboxController = [[SMUnifiedMailboxController alloc] init];
        _outboxController = [[SMOutboxController alloc] initWithUserAccount:self];
    }
    
    SM_LOG_DEBUG(@"user account initialized");
    
    return self;
}

- (SMDatabase*)database {
    SM_FATAL(@"no database instance in the unified account");
    return nil;
}

- (void)fetchMessageInlineAttachments:(SMMessage*)message {
    SM_FATAL(@"TODO");
}

@end
