//
//  SMLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMMessageStorage.h"
#import "SMNotificationsController.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMOperationExecutor.h"
#import "SMOpMoveMessages.h"
#import "SMOpDeleteMessages.h"
#import "SMOpSetMessageFlags.h"
#import "SMMessageListController.h"
#import "SMMessageThread.h"
#import "SMMessageThreadDescriptor.h"
#import "SMMessageThreadDescriptorEntry.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMDatabase.h"
#import "SMOutboxController.h"
#import "SMNotificationsController.h"
#import "SMAddress.h"
#import "SMFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolderMessageBodyFetchQueue.h"
#import "SMLocalFolder.h"

@implementation SMLocalFolder {
    NSMutableArray<SMDatabaseOp*> *_dbOps;
}

@synthesize kind = _kind;
@synthesize messageStorage = _messageStorage;
@synthesize localName = _localName;
@synthesize remoteFolderName = _remoteFolderName;
@synthesize unseenMessagesCount = _unseenMessagesCount;
@synthesize totalMessagesCount = _totalMessagesCount;
@synthesize messageHeadersFetched = _messageHeadersFetched;
@synthesize maxMessagesPerThisFolder = _maxMessagesPerThisFolder;
@synthesize syncedWithRemoteFolder = _syncedWithRemoteFolder;

- (id)initWithAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _kind = kind;
        _localName = localFolderName;
        _remoteFolderName = remoteFolderName;
        _messageStorage = [[SMMessageStorage alloc] initWithUserAccount:account];
        _maxMessagesPerThisFolder = DEFAULT_MAX_MESSAGES_PER_FOLDER;
        _unseenMessagesCount = 0;
        _totalMessagesCount = 0;
        _messageHeadersFetched = 0;
        _fetchedMessageHeaders = [NSMutableDictionary new];
        _fetchMessageThreadsHeadersOps = [NSMutableDictionary new];
        _searchMessageThreadsOps = [NSMutableDictionary new];
        _syncedWithRemoteFolder = syncWithRemoteFolder;
        _totalMemory = 0;
        _loadingFromDB = (syncWithRemoteFolder? YES : NO);
        _dbSyncInProgress = NO;
        _dbMessageThreadsLoadsCount = 0;
        _messageBodyFetchQueue = [[SMLocalFolderMessageBodyFetchQueue alloc] initWithUserAccount:account localFolder:self];
        _dbOps = [NSMutableArray array];
    }
    
    return self;
}

- (void)rescheduleMessageListUpdate {
    [[_account messageListController] scheduleMessageListUpdate:NO];
}

- (void)cancelScheduledMessageListUpdate {
    [[_account messageListController] cancelScheduledMessageListUpdate];
}

- (void)cancelScheduledUpdateTimeout {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTimeout) object:nil];
}

- (void)rescheduleUpdateTimeout {
    [self cancelScheduledUpdateTimeout];

    [self performSelector:@selector(updateTimeout) withObject:nil afterDelay:OPERATION_UPDATE_TIMEOUT_SEC];
}

- (void)updateTimeout {
    SM_LOG_WARNING(@"operation timeout");
    
    [self stopLocalFolderSync];
    [self startLocalFolderSync];
    [self rescheduleUpdateTimeout];
}

- (void)startLocalFolderSync {
    [self rescheduleMessageListUpdate];

    if(_dbSyncInProgress || _folderInfoOp != nil || _fetchMessageHeadersOp != nil || _searchMessageThreadsOps.count > 0 || _fetchMessageThreadsHeadersOps.count > 0) {
        SM_LOG_WARNING(@"previous op is still in progress for folder %@", _localName);
        return;
    }

    [[_account localFolderRegistry] keepFoldersMemoryLimit];

    _messageHeadersFetched = 0;
    
    [_messageStorage startUpdate:_localName];
    
    if(_loadingFromDB) {
        _dbSyncInProgress = YES;

        [_dbOps addObject:[[_account database] getMessagesCountInDBFolder:_localName block:^(NSUInteger messagesCount) {
            SM_LOG_DEBUG(@"messagesCount=%lu", messagesCount);

            _totalMessagesCount = messagesCount;
            
            [self syncFetchMessageHeaders];
        }]];
    }
    else {
        MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
        
        NSAssert(session, @"session lost");

        // TODO: handle session reopening/uids validation   
        
        _folderInfoOp = [session folderInfoOperation:_localName];
        _folderInfoOp.urgent = YES;

        [_folderInfoOp start:^(NSError *error, MCOIMAPFolderInfo *info) {
            _folderInfoOp = nil;

            if(error == nil) {
                SM_LOG_DEBUG(@"Folder %@, UIDNEXT: %u, UIDVALIDITY: %u, Messages count %u", _localName, info.uidNext, info.uidValidity, info.messageCount);
                
                _totalMessagesCount = [info messageCount];
                
                [self syncFetchMessageHeaders];
            } else {
                SM_LOG_ERROR(@"Error fetching folder %@ info: %@", _localName, error);
            }
        }];
    }
}

- (void)increaseLocalFolderCapacity {
    if(![self folderUpdateIsInProgress]) {
        if(_messageHeadersFetched + INCREASE_MESSAGES_PER_FOLDER < _totalMessagesCount) {
            _maxMessagesPerThisFolder += INCREASE_MESSAGES_PER_FOLDER;
        }
    }
}

- (void)increaseLocalFolderFootprint:(uint64_t)size {
    _totalMemory += size;
}

- (Boolean)folderUpdateIsInProgress {
    return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)finishMessageHeadersFetching {
    [self recalculateTotalMemorySize];

    BOOL shouldStartRemoteSync = _loadingFromDB && _syncedWithRemoteFolder;
    
    _loadingFromDB = NO;
    _dbSyncInProgress = NO;

    [_fetchedMessageHeaders removeAllObjects];

    if(shouldStartRemoteSync) {
        SM_LOG_INFO(@"folder %@ loaded from the local database, starting syncing with server", _localName);
        
        [self startLocalFolderSync];
    }
    else if(!_loadingFromDB && _syncedWithRemoteFolder) {
        SM_LOG_INFO(@"folder %@ not yet loaded from the local database, syncing with server postponed", _localName);
    }
    else if(!_loadingFromDB && !_syncedWithRemoteFolder) {
        SM_LOG_INFO(@"folder %@ not yet loaded from the local database (but won't be synced with server anyway)", _localName);
    }
    else {
        SM_LOG_INFO(@"folder %@ loaded from the local database, but not synced with server", _localName);
    }
}

- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
    [_messageBodyFetchQueue fetchMessageBody:uid messageDate:messageDate remoteFolder:remoteFolderName threadId:threadId urgent:YES tryLoadFromDatabase:YES];
}

- (void)syncFetchMessageThreadsHeaders {
    SM_LOG_DEBUG(@"fetching %lu threads", _fetchedMessageHeaders.count);

    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    id<SMMailbox> mailbox = [_account mailbox];
    NSString *allMailFolder = [mailbox.allMailFolder fullName];
    
    NSAssert(_searchMessageThreadsOps.count == 0, @"_searchMessageThreadsOps not empty");

    if(allMailFolder == nil) {
        SM_LOG_ERROR(@"no all mail folder, no message threads will be constructed!");

        [self finishHeadersSync:(_loadingFromDB? NO : YES)];
        return;
    }
    
    if(_fetchedMessageHeaders.count == 0) {
        [self finishHeadersSync:(_loadingFromDB? NO : YES)];
        return;
    }

    NSMutableSet *threadIds = [[NSMutableSet alloc] init];
    
    if(_loadingFromDB) {
        for(NSNumber *gmailMessageId in _fetchedMessageHeaders) {
            MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];
            uint64_t threadIdNum = message.gmailThreadID;
            NSNumber *threadId = [NSNumber numberWithUnsignedLongLong:threadIdNum];

            if([threadIds containsObject:threadId])
                continue;
            
            [threadIds addObject:threadId];
            
            [_dbOps addObject:[[_account database] loadMessageThreadFromDB:threadIdNum folder:_remoteFolderName block:^(SMMessageThreadDescriptor *threadDesc) {
                if(threadDesc != nil) {
                    SM_LOG_DEBUG(@"message thread %llu, messages count %lu", threadIdNum, threadDesc.messagesCount);

                    [self fetchMessageThreadsHeadersFromDescriptor:threadDesc];
                }
                
                NSAssert(_dbMessageThreadsLoadsCount > 0, @"bad _dbMessageThreadsLoadsCount");
                _dbMessageThreadsLoadsCount--;
                
                if(_dbMessageThreadsLoadsCount == 0 && _dbMessageThreadHeadersLoadsCount == 0) {
                    // no more threads are loading, and no messages loaded from threads
                    // so stop loading headers now and start bodies fetching
                    [self finishHeadersSync:NO];
                }
            }]];
            
            _dbMessageThreadsLoadsCount++;
        }

        if(_dbMessageThreadsLoadsCount == 0) {
            // no thread loading was started
            // so stop loading headers now and start bodies fetching
            [self finishHeadersSync:NO];
        }
    }
    else {
        for(NSNumber *gmailMessageId in _fetchedMessageHeaders) {
            MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];
            uint64_t threadIdNum = message.gmailThreadID;
            NSNumber *threadId = [NSNumber numberWithUnsignedLongLong:threadIdNum];
            
            if([threadIds containsObject:threadId])
                continue;

            [threadIds addObject:threadId];

            MCOIMAPSearchExpression *expression = [MCOIMAPSearchExpression searchGmailThreadID:threadIdNum];
            MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:allMailFolder expression:expression];
            
            op.urgent = YES;
            
            [op start:^(NSError *error, MCOIndexSet *searchResults) {
                if([_searchMessageThreadsOps objectForKey:threadId] != op)
                    return;

                [self rescheduleUpdateTimeout];
                
                [_searchMessageThreadsOps removeObjectForKey:threadId];
                
                if(error == nil) {
                    SM_LOG_DEBUG(@"Search for message '%@' thread %llu finished (%lu searches left)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);

                    if(searchResults.count > 0) {
                        SM_LOG_DEBUG(@"%u messages found in '%@', threadId %@", [searchResults count], allMailFolder, threadId);
                        
                        [self fetchMessageThreadsHeadersFromAllMailFolder:threadId uids:searchResults updateDatabase:YES];
                    }
                } else {
                    SM_LOG_ERROR(@"search in '%@' for thread %@ failed, error %@", allMailFolder, threadId, error);

                    [self markMessageThreadAsUpdated:threadId];
                }
            }];
            
            [_searchMessageThreadsOps setObject:op forKey:threadId];

            SM_LOG_DEBUG(@"Search for message '%@' thread %llu started (%lu searches active)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);
        }
    }
}

- (void)markMessageThreadAsUpdated:(NSNumber*)threadId {
    [_messageStorage markMessageThreadAsUpdated:[threadId unsignedLongLongValue] localFolder:_localName];
}

- (void)updateMessages:(NSArray*)imapMessages remoteFolder:(NSString*)remoteFolderName updateDatabase:(Boolean)updateDatabase {
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    
    SMMessageStorageUpdateResult updateResult = [_messageStorage updateIMAPMessages:imapMessages localFolder:_localName remoteFolder:remoteFolderName session:session updateDatabase:updateDatabase unseenMessagesCount:&_unseenMessagesCount];
    
    [SMNotificationsController localNotifyMessagesUpdated:_localName updateResult:updateResult account:_account];
}

- (void)fetchMessageThreadsHeadersFromAllMailFolder:(NSNumber*)threadId uids:(MCOIndexSet*)messageUIDs updateDatabase:(Boolean)updateDatabase {
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    id<SMMailbox> mailbox = [_account mailbox];
    NSString *allMailFolder = [mailbox.allMailFolder fullName];

    MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:allMailFolder requestKind:messageHeadersRequestKind uids:messageUIDs];
    
    [op start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
        if([_fetchMessageThreadsHeadersOps objectForKey:threadId] != op)
            return;
        
        [self rescheduleUpdateTimeout];

        [_fetchMessageThreadsHeadersOps removeObjectForKey:threadId];
        
        if(error == nil) {
            NSMutableArray *filteredMessages = [NSMutableArray array];
            for(MCOIMAPMessage *m in messages) {
                if([_fetchedMessageHeaders objectForKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]] == nil) {
                    SM_LOG_DEBUG(@"fetching message body UID %u, gmailId %llu from [all mail]", m.uid, m.gmailMessageID);
                    
                    [_messageBodyFetchQueue fetchMessageBody:m.uid messageDate:[m.header date] remoteFolder:allMailFolder threadId:m.gmailThreadID urgent:NO tryLoadFromDatabase:YES];
                    
                    [filteredMessages addObject:m];
                }
            }

            [self updateMessages:filteredMessages remoteFolder:allMailFolder updateDatabase:(_loadingFromDB? NO : YES)];
        } else {
            SM_LOG_ERROR(@"Error fetching message headers for thread %@: %@", threadId, error);
            
            [self markMessageThreadAsUpdated:threadId];
        }
        
        if(_searchMessageThreadsOps.count == 0 && _fetchMessageThreadsHeadersOps.count == 0) {
            [self finishHeadersSync:updateDatabase];
        }
    }];

    [_fetchMessageThreadsHeadersOps setObject:op forKey:threadId];

    SM_LOG_DEBUG(@"Fetching headers for thread %@ started (%lu fetches active)", threadId, _fetchMessageThreadsHeadersOps.count);
}

- (void)fetchMessageThreadsHeadersFromDescriptor:(SMMessageThreadDescriptor*)threadDesc {
    SMMessageThread *messageThread = [_messageStorage messageThreadById:threadDesc.threadId localFolder:_remoteFolderName];

    if(messageThread == nil) {
        // It is possible that the user has a chance to delete something in the middle of loading from DB.
        SM_LOG_WARNING(@"message thread %llu not found in folder %@, although the first message is loaded", threadDesc.threadId, _remoteFolderName);
        return;
    }

    for(SMMessageThreadDescriptorEntry *entry in threadDesc.entries) {
        if([messageThread getMessageByUID:entry.uid] == nil) {
            SM_LOG_DEBUG(@"Loading message with UID %u from folder '%@' in thread %llu from database", entry.uid, entry.folderName, threadDesc.threadId);

            [_dbOps addObject:[[_account database] loadMessageHeaderForUIDFromDBFolder:entry.folderName uid:entry.uid block:^(MCOIMAPMessage *message) {
                if(message != nil) {
                    SM_LOG_DEBUG(@"message from folder %@ with uid %u for message thread %llu loaded ok", entry.folderName, entry.uid, threadDesc.threadId);
                    SM_LOG_DEBUG(@"fetching message body UID %u, gmailId %llu from [%@]", message.uid, message.gmailMessageID, entry.folderName);
                    
                    [_messageBodyFetchQueue fetchMessageBody:message.uid messageDate:[message.header date] remoteFolder:entry.folderName threadId:message.gmailThreadID urgent:NO tryLoadFromDatabase:YES];
                    
                    [self updateMessages:[NSArray arrayWithObject:message] remoteFolder:entry.folderName updateDatabase:NO];
                }
                else {
                    SM_LOG_INFO(@"message from folder %@ with uid %u for message thread %llu not found in database", entry.folderName, entry.uid, threadDesc.threadId);
                }
                
                NSAssert(_dbMessageThreadHeadersLoadsCount > 0, @"bad _dbMessageThreadHeadersLoadsCount");
                _dbMessageThreadHeadersLoadsCount--;
                
                if(_dbMessageThreadHeadersLoadsCount == 0) {
                    // all message headers from message threads are finally loaded
                    // now it's time to load bodies
                    // so stop loading headers now and start bodies fetching
                    [self finishHeadersSync:NO];
                }
            }]];
            
            _dbMessageThreadHeadersLoadsCount++;
        }
        else {
            SM_LOG_DEBUG(@"Message with UID %u from folder '%@' is already in thread %llu", entry.uid, entry.folderName, threadDesc.threadId);
        }
    }
}

- (void)finishHeadersSync:(Boolean)updateDatabase {
    [self cancelScheduledUpdateTimeout];

    // When the update ends, push a system notification if these conditions are met:
    // 1. It's an update from the server;
    // 2. The folder is the INBOX (TODO: make configurable);
    // 3. The message is new;
    // 4. The message is unseen.
    SMFolder *inboxFolder = [[_account mailbox] inboxFolder];

    NSAssert(inboxFolder != nil, @"inboxFolder is nil");
    
    BOOL shouldUseNotifications = (!_loadingFromDB && [_remoteFolderName isEqualToString:inboxFolder.fullName]);
    
    SMMessageStorageUpdateResult updateResult = [_messageStorage endUpdate:_localName removeFolder:_remoteFolderName removeVanishedMessages:YES updateDatabase:updateDatabase unseenMessagesCount:&_unseenMessagesCount processNewUnseenMessagesBlock:shouldUseNotifications? ^(NSArray *newUnseenMessages) {
        if(newUnseenMessages.count <= MAX_NEW_MESSAGE_NOTIFICATIONS) {
            for(SMMessage *m in newUnseenMessages) {
                SMAddress *from = [[SMAddress alloc] initWithMCOAddress:m.fromAddress];
                [SMNotificationsController systemNotifyNewMessage:from.stringRepresentationShort];
            }
        }
        else {
            [SMNotificationsController systemNotifyNewMessages:newUnseenMessages.count];
        }
    } : nil];

    Boolean hasUpdates = (updateResult != SMMesssageStorageUpdateResultNone);
    
    [self finishMessageHeadersFetching];

    [SMNotificationsController localNotifyMessageHeadersSyncFinished:_localName hasUpdates:hasUpdates account:_account];
}

- (void)updateMessageHeaders:(NSArray*)messages updateDatabase:(Boolean)updateDatabase {
    for(MCOIMAPMessage *m in messages) {
        [_fetchedMessageHeaders setObject:m forKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]];

        SM_LOG_DEBUG(@"fetching message body, gmail message id %llu", m.gmailMessageID);
        
        // TODO: body loading should be cancelled as well as _loadMessageHeadersForUIDsFromDBFolderOp
        // See issue #72.
        [_messageBodyFetchQueue fetchMessageBody:m.uid messageDate:[m.header date] remoteFolder:_remoteFolderName threadId:m.gmailThreadID urgent:NO tryLoadFromDatabase:YES];
    }
    
    _messageHeadersFetched += [messages count];
    
    [self updateMessages:messages remoteFolder:_remoteFolderName updateDatabase:updateDatabase];
}

- (void)syncFetchMessageHeaders {
    NSAssert(_messageHeadersFetched <= _totalMessagesCount, @"invalid messageHeadersFetched");
    
    BOOL finishFetch = YES;
    
    if(_totalMessagesCount == _messageHeadersFetched) {
        SM_LOG_DEBUG(@"all %lu message headers fetched, stopping", _totalMessagesCount);
    } else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
        SM_LOG_DEBUG(@"fetched %lu message headers, stopping", _messageHeadersFetched);
    } else {
        finishFetch = NO;
    }
    
    if(finishFetch) {
        if(_fetchMessageHeadersOp != nil) {
            [_fetchMessageHeadersOp cancel];
            _fetchMessageHeadersOp = nil;
        }
        
        [self syncFetchMessageThreadsHeaders];
        
        return;
    }
    
    if(_loadingFromDB) {
        const NSUInteger numberOfMessagesToFetch = MIN(_totalMessagesCount - _messageHeadersFetched, MESSAGE_HEADERS_TO_FETCH_AT_ONCE);

        [_dbOps addObject:[[_account database] loadMessageHeadersFromDBFolder:_localName offset:_messageHeadersFetched count:numberOfMessagesToFetch getMessagesBlock:^(NSArray *outgoingMessages, NSArray *messages) {
            SM_LOG_INFO(@"outgoing messages loaded: %lu", outgoingMessages.count);
            
            for(SMOutgoingMessage *message in outgoingMessages) {
                [self addMessage:message externalMessage:NO updateDatabase:NO];
                
                _messageHeadersFetched++;
            }

            SM_LOG_INFO(@"messages loaded: %lu", messages.count);

            [self rescheduleUpdateTimeout];
            [self updateMessageHeaders:messages updateDatabase:NO];
            [self syncFetchMessageHeaders];
        }]];
    }
    else {
        const NSUInteger restOfMessages = _totalMessagesCount - _messageHeadersFetched;
        const NSUInteger numberOfMessagesToFetch = MIN(restOfMessages, MESSAGE_HEADERS_TO_FETCH_AT_ONCE);
        const NSUInteger fetchMessagesFromIndex = restOfMessages - numberOfMessagesToFetch + 1;
        
        MCOIndexSet *regionToFetch = [MCOIndexSet indexSetWithRange:MCORangeMake(fetchMessagesFromIndex, numberOfMessagesToFetch - 1)];
        MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
        
        // TODO: handle session reopening/uids validation
        
        NSAssert(session, @"session lost");

        NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
        
        _fetchMessageHeadersOp = [session fetchMessagesByNumberOperationWithFolder:_localName requestKind:messageHeadersRequestKind numbers:regionToFetch];
        
        _fetchMessageHeadersOp.urgent = YES;
        
        [_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
            [self rescheduleUpdateTimeout];

            _fetchMessageHeadersOp = nil;
            
            if(error == nil) {
                [self updateMessageHeaders:messages updateDatabase:YES];
                [self syncFetchMessageHeaders];
            } else {
                SM_LOG_ERROR(@"Error downloading messages list: %@", error);
            }
        }];
    }
}

- (Boolean)messageHeadersAreBeingLoaded {
    return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)stopLocalFolderSync {
    [self cancelScheduledUpdateTimeout];
    
    [_fetchedMessageHeaders removeAllObjects];
    
    [_folderInfoOp cancel];
    _folderInfoOp = nil;
    
    [_fetchMessageHeadersOp cancel];
    _fetchMessageHeadersOp = nil;
    
    for(NSNumber *threadId in _searchMessageThreadsOps) {
        MCOIMAPBaseOperation *op = [_searchMessageThreadsOps objectForKey:threadId];
        [op cancel];
    }
    [_searchMessageThreadsOps removeAllObjects];
    
    for(NSNumber *threadId in _fetchMessageThreadsHeadersOps) {
        MCOIMAPBaseOperation *op = [_fetchMessageThreadsHeadersOps objectForKey:threadId];
        [op cancel];
    }
    [_fetchMessageThreadsHeadersOps removeAllObjects];
    
    [_messageStorage cancelUpdate];

    [_messageBodyFetchQueue stopBodiesLoading];
    
    for(SMDatabaseOp *dbOp in _dbOps) {
        [dbOp cancel];
    }
    
    [_dbOps removeAllObjects];

    _dbSyncInProgress = NO;
}

- (void)addMessage:(SMMessage*)message externalMessage:(BOOL)externalMessage updateDatabase:(BOOL)updateUpdate {
    if([_messageStorage addMessage:message toLocalFolder:_localName updateDatabase:updateUpdate]) {
        if(externalMessage) {
            _totalMessagesCount++;
        }
        
        [SMNotificationsController localNotifyMessagesUpdated:_localName updateResult:SMMesssageStorageUpdateResultStructureChanged account:_account];
    }
}

- (void)addMessage:(SMMessage*)message {
    [self addMessage:message externalMessage:YES updateDatabase:(_kind != SMFolderKindOutbox)];
}

- (void)removeMessage:(SMMessage*)message {
    [_messageStorage removeMessage:message fromLocalFolder:_localName updateDatabase:NO];
    
    NSAssert(_totalMessagesCount > 0, @"_totalMessagesCount is 0");
    _totalMessagesCount--;
    
    [SMNotificationsController localNotifyMessagesUpdated:_localName updateResult:SMMesssageStorageUpdateResultStructureChanged account:_account];
}

- (void)adjustUnseenCount:(BOOL)messageUnseen {
    if(messageUnseen) {
        _unseenMessagesCount++;
    }
    else if(_unseenMessagesCount > 0) {
        _unseenMessagesCount--;
    }
}

#pragma mark Messages manipulation

- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen {
    if(message.unseen == unseen)
        return;
    
    // adjust the folder stats
    if(unseen != message.unseen) {
        [self adjustUnseenCount:unseen];
    }
    
    // set the local message flags
    message.unseen = unseen;

    // update the local database
    [[_account database] updateMessageInDBFolder:message.imapMessage folder:_remoteFolderName];

    // Notify listeners (mailbox, etc).
    [SMNotificationsController localNotifyMessageFlagsUpdates:_localName account:_account];
    
    // enqueue the remote folder operation
    SMOpSetMessageFlags *op = [[SMOpSetMessageFlags alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName kind:(unseen? MCOIMAPStoreFlagsRequestKindRemove : MCOIMAPStoreFlagsRequestKindAdd) flags:MCOMessageFlagSeen operationExecutor:[(SMUserAccount*)_account operationExecutor]];
    
    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
}

- (void)setMessageFlagged:(SMMessage*)message flagged:(Boolean)flagged {
    if(message.flagged == flagged)
        return;
    
    // set the local message flags
    message.flagged = flagged;
    
    // update the local database
    [[_account database] updateMessageInDBFolder:message.imapMessage folder:_remoteFolderName];
    
    // enqueue the remote folder operation
    SMOpSetMessageFlags *op = [[SMOpSetMessageFlags alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName kind:(flagged? MCOIMAPStoreFlagsRequestKindAdd : MCOIMAPStoreFlagsRequestKindRemove) flags:MCOMessageFlagFlagged operationExecutor:[(SMUserAccount*)_account operationExecutor]];
    
    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
}

#pragma mark Messages movement to other remote folders

- (BOOL)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)destRemoteFolderName {
    id<SMMailbox> mailbox = [_account mailbox];
    SMFolder *destFolder = [mailbox getFolderByName:destRemoteFolderName];
    
    if(destFolder == nil) {
        SM_LOG_INFO(@"Destination folder %@ not found", destRemoteFolderName);
        return FALSE;
    }

    if(_kind == SMFolderKindOutbox) {
        if(destFolder.kind != SMFolderKindTrash) {
            SM_LOG_INFO(@"Destination folder %@ (kind %ld) is not Trash", destRemoteFolderName, destFolder.kind);
            return FALSE;
        }
        
        // There are the following steps that must be done:
        // 1) Cancel message sending from the SMTP queue;
        // 2) Remove the messages from the storage for the outbox folder;
        // 3) Put the deleted messages to the local Trash folder.

        for(SMMessageThread *messageThread in messageThreads) {
            for(SMMessage *message in messageThread.messagesSortedByDate) {
                NSAssert([message isKindOfClass:[SMOutgoingMessage class]], @"non-outgoing message %@ found in Outbox", message);
                [[_account outboxController] cancelMessageSending:(SMOutgoingMessage*)message];

                SMFolder *trashFolder = [[_account mailbox] trashFolder];
                SMLocalFolder *trashLocalFolder = [[_account localFolderRegistry] getLocalFolder:trashFolder.fullName];

                NSAssert(trashLocalFolder, @"trashLocalFolder is nil");
                [trashLocalFolder addMessage:message];

                [self removeMessage:message];
            }
        }

        [SMNotificationsController localNotifyMessageFlagsUpdates:_localName account:_account];
        
        return TRUE;
    }

    // Stop current message loading process.
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
    [self stopLocalFolderSync];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
    [self cancelScheduledMessageListUpdate];

    // Remove the deleted message threads from the message storage.
    [_messageStorage deleteMessageThreads:messageThreads fromLocalFolder:_localName updateDatabase:YES unseenMessagesCount:&_unseenMessagesCount];

    // Now, we have to cancel message bodies loading for the deleted messages.
    MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSet];
    for(SMMessageThread *thread in messageThreads) {
        NSArray *messages = [thread messagesSortedByDate];
        
        // Iterate messages for each deleted message thread.
        for(SMMessage *message in messages) {
            // Note that we choose only messages that belong to the current folder.
            // If a message doesn't belong to the folder, it's already in another folder
            // and hence has been shown in this message thread because of its thread id.
            // So leave it alone (skip it).
            if([message.remoteFolder isEqualToString:_remoteFolderName] || [message isKindOfClass:[SMOutgoingMessage class]]) {
                if(![message isKindOfClass:[SMOutgoingMessage class]]) {
                    // Keep the message for later; we'll have to actually move it remotely.
                    // Note that local (outgoing) messages do not require moving.
                    [messagesToMoveUids addIndex:message.uid];
                }

                // Cancel message body fetching.
                [_messageBodyFetchQueue cancelBodyLoading:message.uid remoteFolder:_remoteFolderName];

                // Delete the message from the local database as well.
                [[_account database] removeMessageFromDBFolder:message.uid folder:_remoteFolderName];
            }
        }
    }
    
    // After the local storage is cleared and there is no bodies loading,
    // actually move the messages on the server.
    if(messagesToMoveUids.count != 0) {
        SMOperation *op = nil;
        
        if(_kind == SMFolderKindTrash) {
            op = [[SMOpDeleteMessages alloc] initWithUids:messagesToMoveUids remoteFolderName:_remoteFolderName operationExecutor:[(SMUserAccount*)_account operationExecutor]];

            SM_LOG_INFO(@"Enqueueing deleting of %u messages from remote folder %@", messagesToMoveUids.count, _remoteFolderName);
        }
        else {
            op = [[SMOpMoveMessages alloc] initWithUids:messagesToMoveUids srcRemoteFolderName:_remoteFolderName dstRemoteFolderName:destRemoteFolderName operationExecutor:[(SMUserAccount*)_account operationExecutor]];
            
            SM_LOG_INFO(@"Enqeueing moving of %u messages from remote folder %@ to folder %@", messagesToMoveUids.count, _remoteFolderName, destRemoteFolderName);
        }
        
        [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    }
    
    // Notify observers that message flags have possibly changed.
    [SMNotificationsController localNotifyMessageFlagsUpdates:_localName account:_account];
    
    return TRUE;
}

- (Boolean)moveMessage:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName {
    NSNumber *threadIdNum = [_messageStorage messageThreadByMessageUID:uid]; // TODO: use folder name along with UID!

    const uint64_t threadId = (threadIdNum != nil? [threadIdNum unsignedLongLongValue] : 0);
    const Boolean useThreadId = (threadIdNum != nil);

    return [self moveMessage:uid threadId:threadId useThreadId:useThreadId toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId toRemoteFolder:(NSString*)destRemoteFolderName {
    return [self moveMessage:uid threadId:threadId useThreadId:YES toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId useThreadId:(Boolean)useThreadId toRemoteFolder:(NSString*)destRemoteFolderName {
    NSAssert(![_remoteFolderName isEqualToString:destRemoteFolderName], @"src and dest remove folders are the same %@", _remoteFolderName);

    // Stop current message loading process.
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
    [self stopLocalFolderSync];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
    [self cancelScheduledMessageListUpdate];

    // Remove the deleted message from the current folder in the message storage.
    // This is necessary to immediately reflect the visual change.
    Boolean needUpdateMessageList = NO;
    
    if(useThreadId) {
        needUpdateMessageList = [_messageStorage deleteMessageFromStorage:uid threadId:threadId localFolder:_localName remoteFolder:_remoteFolderName unseenMessagesCount:&_unseenMessagesCount];

        // Notify observers that message flags have possibly changed.
        [SMNotificationsController localNotifyMessageFlagsUpdates:_localName account:_account];
    }
    else {
        // TODO: Should we adjust folder stats (unseen count)?
    }
    
    // Now, we have to cancel message bodies loading for the deleted messages.
    MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSetWithIndex:uid];
    
    // Cancel message body fetching.
    [_messageBodyFetchQueue cancelBodyLoading:uid remoteFolder:_remoteFolderName];

    // Delete the message from the local database.
    [[_account database] removeMessageFromDBFolder:uid folder:_remoteFolderName];

    // After the local storage is cleared and there is no bodies loading,
    // actually move the messages on the server.
    SMOpMoveMessages *op = [[SMOpMoveMessages alloc] initWithUids:messagesToMoveUids srcRemoteFolderName:_remoteFolderName dstRemoteFolderName:destRemoteFolderName operationExecutor:[(SMUserAccount*)_account operationExecutor]];
    
    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    
    return needUpdateMessageList;
}

#pragma mark Memory management

- (void)reclaimMemory:(uint64_t)memoryToReclaimKb {
    if(memoryToReclaimKb == 0)
        return;

    uint64_t reclaimedMemory = 0;
    NSUInteger reclaimedMessagesCount = 0;
    Boolean stop = NO;

    NSUInteger threadsCount = [_messageStorage messageThreadsCount];
    for(NSUInteger i = threadsCount; !stop && i > 0; i--) {
        SMMessageThread *thread = [_messageStorage messageThreadAtIndexByDate:(i-1) localFolder:_localName];
        NSArray *messages = [thread messagesSortedByDate];
        
        for(NSUInteger j = messages.count; j > 0; j--) {
            SMMessage *message = messages[j-1];
            
            if(![message isKindOfClass:[SMOutgoingMessage class]]) {
                if([message hasData] && message.messageSize > 0) {
                    reclaimedMessagesCount++;
                    reclaimedMemory += message.messageSize;

                    [message reclaimData];
                    
                    if(reclaimedMemory / 1024 >= memoryToReclaimKb) {
                        stop = YES;
                        break;
                    }
                }
            }
        }
    }
    
    NSAssert(_totalMemory >= reclaimedMemory, @"_totalMemory %llu < reclaimedMemory %llu", _totalMemory, reclaimedMemory);
    
    _totalMemory -= reclaimedMemory;

    SM_LOG_DEBUG(@"total reclaimed %llu Kb in %lu messages, %llu Kb left in folder %@", reclaimedMemory / 1024 ,reclaimedMessagesCount, _totalMemory / 1024, _localName);
}

- (void)recalculateTotalMemorySize {
    _totalMemory = 0;

    NSUInteger threadsCount = [_messageStorage messageThreadsCount];
    for(NSUInteger i = 0; i < threadsCount; i++) {
        SMMessageThread *thread = [_messageStorage messageThreadAtIndexByDate:i localFolder:_localName];

        for(SMMessage *message in [thread messagesSortedByDate]) {
            if([message hasData]) {
                _totalMemory += message.messageSize;
            }
        }
    }

    SM_LOG_DEBUG(@"total memory %llu Kb in folder %@", _totalMemory / 1024, _localName);
}

- (uint64_t)getTotalMemoryKb {
    return _totalMemory / 1024;
}

@end
