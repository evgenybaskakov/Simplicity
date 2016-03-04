//
//  SMLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

#import "SMFolder.h"

// TODO: move to advanced settings
static const NSUInteger DEFAULT_MAX_MESSAGES_PER_FOLDER = 500000;
static const NSUInteger INCREASE_MESSAGES_PER_FOLDER = 50;
static const NSUInteger MESSAGE_HEADERS_TO_FETCH_AT_ONCE = 200;
static const NSUInteger OPERATION_UPDATE_TIMEOUT_SEC = 30;
static const NSUInteger MAX_NEW_MESSAGE_NOTIFICATIONS = 5;

static const MCOIMAPMessagesRequestKind messageHeadersRequestKind = (MCOIMAPMessagesRequestKind)(
    MCOIMAPMessagesRequestKindUid |
    MCOIMAPMessagesRequestKindFlags |
    MCOIMAPMessagesRequestKindHeaders |
    MCOIMAPMessagesRequestKindStructure |
    MCOIMAPMessagesRequestKindInternalDate |
    MCOIMAPMessagesRequestKindFullHeaders |
    MCOIMAPMessagesRequestKindHeaderSubject |
    MCOIMAPMessagesRequestKindGmailLabels |
    MCOIMAPMessagesRequestKindGmailMessageID |
    MCOIMAPMessagesRequestKindGmailThreadID |
    MCOIMAPMessagesRequestKindExtraHeaders |
    MCOIMAPMessagesRequestKindSize
);

@class SMLocalFolderMessageBodyFetchQueue;
@class SMMessageStorage;
@class SMMessage;

@interface SMLocalFolder : NSObject {
    @protected SMFolderKind _kind;
    @protected NSString *_localName;
    @protected NSString *_remoteFolderName;
    @protected NSUInteger _unseenMessagesCount;
    @protected NSUInteger _totalMessagesCount;
    @protected NSUInteger _messageHeadersFetched;
    @protected NSUInteger _maxMessagesPerThisFolder;
    @protected Boolean _syncedWithRemoteFolder;
    @protected SMMessageStorage *_messageStorage;
    @protected MCOIMAPFolderInfoOperation *_folderInfoOp;
    @protected MCOIMAPFetchMessagesOperation *_fetchMessageHeadersOp;
    @protected NSMutableDictionary *_searchMessageThreadsOps;
    @protected NSMutableDictionary *_fetchMessageThreadsHeadersOps;
    @protected NSMutableDictionary *_fetchedMessageHeaders;
    @protected uint64_t _totalMemory;
    @protected BOOL _loadingFromDB;
    @protected BOOL _dbSyncInProgress;
    @protected NSUInteger _dbMessageThreadsLoadsCount;
    @protected NSUInteger _dbMessageThreadHeadersLoadsCount;
    @protected SMLocalFolderMessageBodyFetchQueue *_messageBodyFetchQueue;
}

@property (readonly) SMFolderKind kind;
@property (readonly) SMMessageStorage *messageStorage;
@property (readonly) NSString *localName;
@property (readonly) NSString *remoteFolderName;
@property (readonly) NSUInteger unseenMessagesCount;
@property (readonly) NSUInteger totalMessagesCount;
@property (readonly) NSUInteger messageHeadersFetched;
@property (readonly) NSUInteger maxMessagesPerThisFolder;
@property (readonly) Boolean syncedWithRemoteFolder;

- (id)initWithLocalFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder;

// increases local folder capacity and forces update
- (void)increaseLocalFolderCapacity;

// increases the memory amount implicitly occupied by this folder
- (void)increaseLocalFolderFootprint:(uint64_t)size;

// these two methods are used to sync the content of this folder
// with the remote folder with the same name
- (void)startLocalFolderSync;

// urgently fetches the body of the message specified by its UID
- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId;

// tells whether there is message headers loading progress underway
- (Boolean)messageHeadersAreBeingLoaded;

// stops message headers and, optionally, bodies loading
- (void)stopMessagesLoading:(Boolean)stopBodiesLoading;

// Adds a new message to the folder.
// Ensures that the folder consistency and sorting order are not changed.
// Can only happen if there's no update ongoing at the current moment.
- (void)addMessage:(SMMessage*)message;

// Removes the given message from the folder.
// Ensures that the folder consistency and sorting order are not changed.
// Can only happen if there's no update ongoing at the current moment.
- (void)removeMessage:(SMMessage*)message;

// sets/clears the unseen flag
- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen;

// sets/clears the "flag" mark
- (void)setMessageFlagged:(SMMessage*)message flagged:(Boolean)flagged;

// initiates process of moving the selected message to another (remote) folder
- (Boolean)moveMessage:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName;

// initiates process of moving the selected message to another (remote) folder
- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId toRemoteFolder:(NSString*)destRemoteFolderName;

// starts asynchronous process of moving the messages from the selected message threads
// to the chosen folder
- (BOOL)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)remoteFolderName;

// frees the occupied memory until the requested amount is reclaimed
// or there is nothing to reclaim within this folder
- (void)reclaimMemory:(uint64_t)memoryToReclaimKb;

// returns the memory amount occupied by messages within this folder
// that can be reclaimed upon request
- (uint64_t)getTotalMemoryKb;

#pragma mark Protected methods

- (void)updateMessages:(NSArray*)imapMessages remoteFolder:(NSString*)remoteFolderName updateDatabase:(Boolean)updateDatabase;
- (void)updateMessageHeaders:(NSArray*)messages updateDatabase:(Boolean)updateDatabase;
- (void)finishMessageHeadersFetching;

@end
