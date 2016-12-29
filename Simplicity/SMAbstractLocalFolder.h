//
//  SMAbstractLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMFolder.h"

@protocol SMAbstractMessageStorage;

@class SMMessage;
@class SMMessageStorage;
@class SMMessageThread;

@protocol SMAbstractLocalFolder

@property (readonly) SMFolderKind kind;
@property (readonly) NSString *localName;
@property (readonly) NSString *remoteFolderName;
@property (readonly) NSUInteger unseenMessagesCount;
@property (readonly) NSUInteger totalMessagesCount;
@property (readonly) NSUInteger messageHeadersFetched;
@property (readonly) NSUInteger maxMessagesPerThisFolder;
@property (readonly) BOOL syncedWithRemoteFolder;

@property (readonly) id<SMAbstractMessageStorage> messageStorage;

// increases local folder capacity and forces update
- (void)increaseLocalFolderCapacity;

// these two methods are used to sync the content of this folder
// with the remote folder with the same name
- (void)startLocalFolderSync;

// stops message headers and bodies loading
- (void)stopLocalFolderSync:(BOOL)stopBodyLoading;

// urgently fetches the body of the message specified by its UID
- (void)fetchMessageBodyUrgentlyWithUID:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId;

// tells whether there is still the initial server sync pending
// and nothing was loaded from the DB
- (BOOL)folderStillLoadingInitialState;

// Adds a new message to the folder.
// Ensures that the folder consistency and sorting order are not changed.
// TODO: remove?
- (void)addMessage:(SMMessage*)message;

// Removes the given message from the folder.
// Ensures that the folder consistency and sorting order are not changed.
// TODO: remove?
- (void)removeMessage:(SMMessage*)message;

// sets/clears the unseen flag
- (void)setMessageUnseen:(SMMessage*)message unseen:(BOOL)unseen;

// sets/clears the "flag" mark
- (void)setMessageFlagged:(SMMessage*)message flagged:(BOOL)flagged;

// initiates process of moving the given message to another (remote) folder
- (BOOL)moveMessage:(uint64_t)messageId uid:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName;

// initiates process of moving the selected message to another (remote) folder
- (BOOL)moveMessage:(SMMessage*)message withinMessageThread:(SMMessageThread*)messageThread toRemoteFolder:(NSString*)destRemoteFolderName;

// starts asynchronous process of moving the messages from the selected message threads
// to the chosen folder
- (BOOL)moveMessageThread:(SMMessageThread*)messageThread toRemoteFolder:(NSString*)destRemoteFolderName;

// adds a label for all messages in the message thread
// initiates a remote server operation
- (void)addMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label;

// removes a label for all messages in the message thread
// initiates a remote server operation
- (BOOL)removeMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label;

@end
