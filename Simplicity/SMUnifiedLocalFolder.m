//
//  SMUnifiedLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAbstractAccount.h"
#import "SMUnifiedLocalFolder.h"

@implementation SMUnifiedLocalFolder

@synthesize kind = _kind;
@synthesize messageStorage = _messageStorage;
@synthesize localName = _localName;
@synthesize remoteFolderName = _remoteFolderName;
@synthesize unseenMessagesCount = _unseenMessagesCount;
@synthesize totalMessagesCount = _totalMessagesCount;
@synthesize messageHeadersFetched = _messageHeadersFetched;
@synthesize maxMessagesPerThisFolder = _maxMessagesPerThisFolder;
@synthesize syncedWithRemoteFolder = _syncedWithRemoteFolder;

- (id)initWithAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName kind:(SMFolderKind)kind {
    self = [super initWithUserAccount:account];
    
    if(self) {
        NSAssert(account.unified, @"unified local folder can only be created for the unified account");
        
        _localName = localFolderName;
        _kind = kind;
    }
    
    return self;
}

- (void)increaseLocalFolderCapacity {
    SM_LOG_WARNING(@"TODO");
}

- (void)increaseLocalFolderFootprint:(uint64_t)size {
    SM_LOG_WARNING(@"TODO");
}

- (void)startLocalFolderSync {
    SM_LOG_WARNING(@"TODO");
}

- (void)stopLocalFolderSync {
    SM_LOG_WARNING(@"TODO");
}

- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
    SM_LOG_WARNING(@"TODO");
}

- (Boolean)messageHeadersAreBeingLoaded {
    SM_LOG_WARNING(@"TODO");
    return NO;
}

- (void)addMessage:(SMMessage*)message {
    SM_LOG_WARNING(@"TODO");
}

- (void)removeMessage:(SMMessage*)message {
    SM_LOG_WARNING(@"TODO");
}

- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen {
    SM_LOG_WARNING(@"TODO");
}

- (void)setMessageFlagged:(SMMessage*)message flagged:(Boolean)flagged {
    SM_LOG_WARNING(@"TODO");
}

- (Boolean)moveMessage:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName {
    SM_LOG_WARNING(@"TODO");
    return NO;
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId toRemoteFolder:(NSString*)destRemoteFolderName {
    SM_LOG_WARNING(@"TODO");
    return NO;
}

- (BOOL)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)remoteFolderName {
    SM_LOG_WARNING(@"TODO");
    return NO;
}

- (void)reclaimMemory:(uint64_t)memoryToReclaimKb {
    SM_LOG_WARNING(@"TODO");
}

- (uint64_t)getTotalMemoryKb {
    SM_LOG_WARNING(@"TODO");
    return 0;
}

@end
