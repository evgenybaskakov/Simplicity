//
//  SMUnifiedLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMLocalFolder.h"
#import "SMUnifiedAccount.h"
#import "SMUnifiedMessageStorage.h"
#import "SMUnifiedLocalFolder.h"

@implementation SMUnifiedLocalFolder {
    NSMutableArray<SMLocalFolder*> *_attachedLocalFolders;
}

@synthesize kind = _kind;
@synthesize messageStorage = _messageStorage;
@synthesize localName = _localName;
@synthesize remoteFolderName = _remoteFolderName;
@synthesize messageHeadersFetched = _messageHeadersFetched;
@synthesize maxMessagesPerThisFolder = _maxMessagesPerThisFolder;
@synthesize syncedWithRemoteFolder = _syncedWithRemoteFolder;

- (id)initWithAccount:(SMUnifiedAccount*)account localFolderName:(NSString*)localFolderName kind:(SMFolderKind)kind {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _localName = localFolderName;
        _kind = kind;
        _attachedLocalFolders = [NSMutableArray array];
        _messageStorage = [[SMUnifiedMessageStorage alloc] initWithUserAccount:account localFolder:self];
    }
    
    return self;
}

- (void)attachLocalFolder:(SMLocalFolder*)localFolder {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    SM_LOG_INFO(@"Unified folder %@: attaching folder %@ from account %lu", _localName, localFolder.localName, [appDelegate.accounts indexOfObject:(SMUserAccount*)localFolder.account]);
    
    NSAssert([_attachedLocalFolders indexOfObject:localFolder] == NSNotFound, @"folder %@ already attached", localFolder.localName);
    
    [_attachedLocalFolders addObject:localFolder];
    
    [(SMUnifiedMessageStorage*)_messageStorage attachMessageStorage:(SMMessageStorage*)localFolder.messageStorage];
}

- (void)detachLocalFolder:(SMLocalFolder*)localFolder {
    [(SMUnifiedMessageStorage*)_messageStorage detachMessageStorage:(SMMessageStorage*)localFolder.messageStorage];

    [_attachedLocalFolders removeObject:localFolder];
}

- (NSUInteger)totalMessagesCount {
    NSUInteger count = 0;
    
    for(SMLocalFolder *localFolder in _attachedLocalFolders) {
        count += localFolder.totalMessagesCount;
    }
    
    return count;
}

- (NSUInteger)unseenMessagesCount {
    NSUInteger count = 0;
    
    for(SMLocalFolder *localFolder in _attachedLocalFolders) {
        count += localFolder.unseenMessagesCount;
    }
    
    return count;
}

- (void)increaseLocalFolderCapacity {
    // Nothing to do
}

- (void)increaseLocalFolderFootprint:(uint64_t)size {
    // Nothing to do
}

- (void)startLocalFolderSync {
    // Nothing to do
}

- (void)stopLocalFolderSync {
    // Nothing to do
}

- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
}

- (Boolean)messageHeadersAreBeingLoaded {
    SM_FATAL(@"TODO");
    return NO;
}

- (void)addMessage:(SMMessage*)message {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
}

- (void)removeMessage:(SMMessage*)message {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
}

- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
}

- (void)setMessageFlagged:(SMMessage*)message flagged:(Boolean)flagged {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
}

- (Boolean)moveMessage:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
    return NO;
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId toRemoteFolder:(NSString*)destRemoteFolderName {
    SM_FATAL(@"Stubbed implementation: this must be redirected to the owning local folder");
    return NO;
}

- (BOOL)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)remoteFolderName {
    SM_FATAL(@"TODO");
    return NO;
}

- (void)reclaimMemory:(uint64_t)memoryToReclaimKb {
    // Nothing to do
}

- (uint64_t)getTotalMemoryKb {
    // Nothing to do
    return 0;
}

@end
