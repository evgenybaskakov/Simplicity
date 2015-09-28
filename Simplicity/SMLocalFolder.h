//
//  SMLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMessage;

@interface SMLocalFolder : NSObject

@property (readonly) NSString *localName;
@property (readonly) NSString *remoteFolderName;
@property (readonly) uint64_t totalMessagesCount;
@property (readonly) uint64_t messageHeadersFetched;
@property (readonly) uint64_t maxMessagesPerThisFolder;
@property (readonly) Boolean syncedWithRemoteFolder;

- (id)initWithLocalFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName syncWithRemoteFolder:(Boolean)syncWithRemoteFolder;

// increases local folder capacity and forces update
- (void)increaseLocalFolderCapacity;

// these two methods are used to sync the content of this folder
// with the remote folder with the same name
- (void)startLocalFolderSync;

// loads the messages specified by their UIDs from the remote folder
- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs;

// fetches the body of the message specified by its UID
- (void)fetchMessageBody:(uint32_t)uid remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent;

// tells whether there is message headers loading progress underway
- (Boolean)messageHeadersAreBeingLoaded;

// stops message headers and, optionally, bodies loading
- (void)stopMessagesLoading:(Boolean)stopBodiesLoading;

// stops message headers and bodies loading; also stops sync, if any
// then removes the local folder contents (does not affect the remote folder, if any)
- (void)clear;

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
- (void)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)remoteFolderName;

// frees the occupied memory until the requested amount is reclaimed
// or there is nothing to reclaim within this folder
- (void)reclaimMemory:(uint64_t)memoryToReclaimKb;

// returns the memory amount occupied by messages within this folder
// that can be reclaimed upon request
- (uint64_t)getTotalMemoryKb;

@end
