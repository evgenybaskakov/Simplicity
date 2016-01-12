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

@class SMMessageStorage;
@class SMMessage;

@interface SMLocalFolder : NSObject

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

// loads the messages specified by their UIDs from the remote folder
- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs;

// urgently fetches the body of the message specified by its UID
- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId;

// tells whether there is message headers loading progress underway
- (Boolean)messageHeadersAreBeingLoaded;

// stops message headers and, optionally, bodies loading
- (void)stopMessagesLoading:(Boolean)stopBodiesLoading;

// stops message headers and bodies loading; also stops sync, if any
// then removes the local folder contents (does not affect the remote folder, if any)
- (void)clearMessages;

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

@end
