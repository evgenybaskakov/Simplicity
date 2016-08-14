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
#import "SMOpAddLabel.h"
#import "SMOpRemoveLabel.h"
#import "SMMessageListController.h"
#import "SMMessageThread.h"
#import "SMMessage.h"
#import "SMMessageComparators.h"
#import "SMOutgoingMessage.h"
#import "SMMailbox.h"
#import "SMAccountMailbox.h"
#import "SMDatabase.h"
#import "SMOutboxController.h"
#import "SMNotificationsController.h"
#import "SMAddress.h"
#import "SMFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageBodyFetchQueue.h"
#import "SMLocalFolder.h"

@implementation SMLocalFolder {
    NSMutableArray<SMDatabaseOp*> *_dbOps;
    NSUInteger _serverSyncCount;
    BOOL _hadMessages;
    BOOL _useProvidedUnseenMessagesCount;
    BOOL _finishingFetch;
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
@synthesize messageBodyFetchQueue = _messageBodyFetchQueue;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    self = [super initWithUserAccount:account];
    
    if(self) {
        _kind = kind;
        _localName = localFolderName;
        _remoteFolderName = remoteFolderName;
        _messageStorage = [[SMMessageStorage alloc] initWithUserAccount:account localFolder:self];
        _messageBodyFetchQueue = [[SMMessageBodyFetchQueue alloc] initWithUserAccount:account];
        _maxMessagesPerThisFolder = DEFAULT_MAX_MESSAGES_PER_FOLDER;
        _totalMessagesCount = 0;
        _messageHeadersFetched = 0;
        _fetchedMessageHeaders = [NSMutableDictionary new];
        _searchMessageThreadsOps = [NSMutableDictionary new];
        _syncedWithRemoteFolder = syncWithRemoteFolder;
        _loadingFromDB = (syncWithRemoteFolder? YES : NO);
        _dbSyncInProgress = NO;
        _dbMessageThreadsLoadsCount = 0;
        _dbOps = [NSMutableArray array];
        _serverSyncCount = 0;
        _unseenMessagesCount = 0;
        _useProvidedUnseenMessagesCount = NO;
    }
    
    return self;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
    self = [self initWithUserAccount:account localFolderName:localFolderName remoteFolderName:remoteFolderName kind:kind syncWithRemoteFolder:syncWithRemoteFolder];
    
    if(self) {
        _unseenMessagesCount = initialUnreadCount;
        _useProvidedUnseenMessagesCount = YES;
    }
    
    return self;
}

- (NSUInteger)unseenMessagesCount {
    if(_useProvidedUnseenMessagesCount) {
        return _unseenMessagesCount;
    }

    if(_kind == SMFolderKindDrafts || _kind == SMFolderKindOutbox) {
        return _totalMessagesCount;
    }
    else {
        return _unseenMessagesCount;
    }
}

- (Boolean)folderStillLoadingInitialState {
    if(_kind == SMFolderKindOutbox) {
        // Outbox is always up-to-date.
        return NO;
    }
    
    return !_loadingFromDB && !_hadMessages && _serverSyncCount == 0;
}

- (void)startLocalFolderSync {
    if(_dbSyncInProgress || _folderInfoOp != nil || _fetchMessageHeadersOp != nil || _dbMessageThreadsLoadsCount > 0 || _searchMessageThreadsOps.count > 0) {
        SM_LOG_WARNING(@"previous op is still in progress for folder %@", _localName);
        return;
    }

    SM_LOG_INFO(@"Local folder %@ is syncing", _localName);

    NSAssert(_dbOps.count == 0, @"db ops still pending");

    _messageHeadersFetched = 0;
    
    [_messageStorage startUpdate];
    
    if(_loadingFromDB) {
        _dbSyncInProgress = YES;

        [_dbOps addObject:[[_account database] getMessagesCountInDBFolder:_remoteFolderName block:^(SMDatabaseOp *op, NSUInteger messagesCount) {
            SM_LOG_DEBUG(@"messagesCount=%lu", messagesCount);

            [_dbOps removeObject:op];
            
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

                [SMNotificationsController localNotifyAccountSyncError:(SMUserAccount*)_account error:error.localizedDescription];
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

- (Boolean)folderUpdateIsInProgress {
    return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)finishMessageHeadersFetching {
    BOOL shouldStartRemoteSync = _loadingFromDB && _syncedWithRemoteFolder;
    
    _finishingFetch = NO;
    _loadingFromDB = NO;
    _dbSyncInProgress = NO;
    _useProvidedUnseenMessagesCount = NO;

    [_fetchedMessageHeaders removeAllObjects];
    
    for(SMDatabaseOp *dbOp in _dbOps) {
        [dbOp cancel];
    }
    
    [_dbOps removeAllObjects];

    if(shouldStartRemoteSync) {
        SM_LOG_INFO(@"folder %@ loaded from the local database, starting syncing with server", _localName);
        
        [self startLocalFolderSync];
    }
    else if(!_loadingFromDB && _syncedWithRemoteFolder) {
        SM_LOG_INFO(@"folder %@ already synced with server", _localName);
    }
    else if(!_loadingFromDB && !_syncedWithRemoteFolder) {
        SM_LOG_INFO(@"folder %@ not yet loaded from the local database (but won't be synced with server anyway)", _localName);
    }
    else {
        SM_LOG_INFO(@"folder %@ loaded from the local database, but not synced with server", _localName);
    }
}

- (void)fetchMessageBodyUrgentlyWithUID:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId {
    [_messageBodyFetchQueue fetchMessageBodyWithUID:uid messageId:messageId threadId:threadId messageDate:messageDate urgent:YES tryLoadFromDatabase:YES remoteFolder:remoteFolderName localFolder:self];
}

- (void)syncFetchMessageThreadsHeaders {
    NSAssert(_searchMessageThreadsOps.count == 0, @"_searchMessageThreadsOps not empty");

    BOOL updateDatabase = _loadingFromDB? NO : YES;
    
    if(_fetchedMessageHeaders.count == 0) {
        [self finishHeadersSync:updateDatabase];
        return;
    }
    
    if(_dbMessageThreadsLoadsCount == 0) {
        // no thread loading was started
        // so stop loading headers now and start bodies fetching
        [self finishHeadersSync:updateDatabase];
        return;
    }
    
    SM_LOG_INFO(@"folder %@ waiting for message thread headers sync", _localName);
}

- (void)markMessageThreadAsUpdated:(NSNumber*)threadId {
    [_messageStorage markMessageThreadAsUpdated:[threadId unsignedLongLongValue]];
}

- (void)updateMessages:(NSArray*)imapMessages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags remoteFolder:(NSString*)remoteFolderName updateDatabase:(Boolean)updateDatabase newMessages:(NSMutableArray<MCOIMAPMessage*>*)newMessages {
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    
    NSUInteger *unseenMessagesCountPtr = (_useProvidedUnseenMessagesCount? nil : &_unseenMessagesCount);
    SMMessageStorageUpdateResult updateResult = [_messageStorage updateIMAPMessages:imapMessages plainTextBodies:plainTextBodies hasAttachmentsFlags:hasAttachmentsFlags remoteFolder:remoteFolderName session:session updateDatabase:updateDatabase unseenMessagesCount:unseenMessagesCountPtr newMessages:newMessages];
    
    [SMNotificationsController localNotifyMessagesUpdated:self updateResult:updateResult account:(SMUserAccount*)_account];
}

- (void)loadMessageThread:(uint64_t)threadId remoteFolder:(NSString*)remoteFolder mcoMessages:(NSArray<MCOIMAPMessage*>*)mcoMessages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags {
    if(mcoMessages.count == 0) {
        // 0 means that there's no such thread in this remote folder at all
        return;
    }
    
    SM_LOG_DEBUG(@"message thread %llu, messages count %lu", threadId, mcoMessages.count);
    
    SMMessageThread *messageThread = [_messageStorage messageThreadById:threadId];
    if(messageThread == nil) {
        // It is possible that the user had a chance to delete something in the middle of loading from DB.
        SM_LOG_WARNING(@"message thread %llu not found in folder %@, although the first message is loaded", threadId, _remoteFolderName);
        return;
    }

    for(NSUInteger i = 0; i < mcoMessages.count; i++) {
        MCOIMAPMessage *mcoMessage = mcoMessages[i];
        NSString *plainTextBody = plainTextBodies[i];
        NSNumber *hasAttachmentsFlag = hasAttachmentsFlags[i];
        
        if([messageThread getMessageByMessageId:mcoMessage.gmailMessageID] != nil) {
            // Skip messages already present in this thread
            continue;
        }
        
        SM_LOG_DEBUG(@"message from folder %@ with id %llu for message thread %llu loaded ok", remoteFolder, mcoMessage.gmailMessageID, threadId);
        NSAssert(threadId == mcoMessage.gmailThreadID, @"message thread ID %llu doesn't match the message thread ID %llu", threadId, mcoMessage.gmailThreadID);
        
        if(plainTextBody == nil) {
            plainTextBody = (NSString*)[NSNull null];

            SM_LOG_DEBUG(@"fetching message body UID %u, gmailId %llu from [%@]", mcoMessage.uid, mcoMessage.gmailMessageID, remoteFolder);

            SMMessageBodyFetchQueue *bodyFetchQueue = [self chooseBackgroundOrForegroundMessageBodyFetchQueue];
            
            // TODO: revisit urgency; the user may be looking at this thread
            [bodyFetchQueue fetchMessageBodyWithUID:mcoMessage.uid messageId:mcoMessage.gmailMessageID threadId:threadId messageDate:[mcoMessage.header date] urgent:NO tryLoadFromDatabase:NO remoteFolder:remoteFolder localFolder:self];
        }
        
        [self updateMessages:@[mcoMessage] plainTextBodies:@[plainTextBody] hasAttachmentsFlags:@[hasAttachmentsFlag] remoteFolder:remoteFolder updateDatabase:NO newMessages:nil];
    }
}

- (SMMessageBodyFetchQueue*)chooseBackgroundOrForegroundMessageBodyFetchQueue {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    if([[appDelegate.currentAccount messageListController] localFolderIsCurrent:self]) {
        return _messageBodyFetchQueue;
    }
    else {
        return [(SMUserAccount*)_account backgroundMessageBodyFetchQueue];
    }
}

- (void)finishHeadersSync:(Boolean)updateDatabase {
    SM_LOG_INFO(@"folder %@ is finishing syncing", _localName);

    // When the update ends, push a system notification if these conditions are met:
    // 1. It's an update from the server;
    // 2. The folder is the INBOX (TODO: make configurable);
    // 3. The message is new;
    // 4. The message is unseen.
    SMFolder *inboxFolder = [[_account mailbox] inboxFolder];

    NSAssert(inboxFolder != nil, @"inboxFolder is nil");
    
    BOOL shouldUseNotifications = (!_loadingFromDB && [_remoteFolderName isEqualToString:inboxFolder.fullName]);
    
    NSUInteger *unseenMessagesCountPtr = (_useProvidedUnseenMessagesCount? nil : &_unseenMessagesCount);
    SMMessageStorageUpdateResult updateResult = [_messageStorage endUpdateWithRemoteFolder:_remoteFolderName removeVanishedMessages:YES updateDatabase:updateDatabase unseenMessagesCount:unseenMessagesCountPtr processNewUnseenMessagesBlock:shouldUseNotifications? ^(NSArray *newUnseenMessages) {
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

    Boolean finishedDbSync = _dbSyncInProgress;
    
    [self finishMessageHeadersFetching];

    // Tell everybody we have updates if we just finished loading from the DB or
    // updated from the server for the first time.
    // So the view controllers will have a chance to hide their DB and server sync progress indicators.
    Boolean hasUpdates = (finishedDbSync || _serverSyncCount == 1 || updateResult != SMMesssageStorageUpdateResultNone);
    
    [SMNotificationsController localNotifyMessageHeadersSyncFinished:self hasUpdates:hasUpdates account:(SMUserAccount*)_account];
}

- (void)updateMessageHeaders:(NSArray<MCOIMAPMessage*>*)messages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags updateDatabase:(Boolean)updateDatabase newMessages:(NSMutableArray<MCOIMAPMessage*>*)newMessages {
    for(MCOIMAPMessage *m in messages) {
        [_fetchedMessageHeaders setObject:m forKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]];
    }

    _messageHeadersFetched += [messages count];
    
    [self updateMessages:messages plainTextBodies:plainTextBodies hasAttachmentsFlags:hasAttachmentsFlags remoteFolder:_remoteFolderName updateDatabase:updateDatabase newMessages:newMessages];
}

- (void)syncNewMessages:(NSArray<MCOIMAPMessage*>*)mcoMessages mcoMessagePlainTextBodies:(NSArray<NSString*>*)mcoMessagePlainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags updateDatabase:(BOOL)updateDatabase newMessages:(NSMutableArray<MCOIMAPMessage*>**)pNewMessages {
    NSMutableArray<MCOIMAPMessage*> *newMessages = [NSMutableArray array];

    [self updateMessageHeaders:mcoMessages plainTextBodies:mcoMessagePlainTextBodies hasAttachmentsFlags:hasAttachmentsFlags updateDatabase:updateDatabase newMessages:newMessages];
    
    if(_kind == SMFolderKindDrafts || _kind == SMFolderKindOutbox || _kind == SMFolderKindAllMail || _kind == SMFolderKindSent || _kind == SMFolderKindSpam) {
        for(MCOIMAPMessage *m in newMessages) {
            [self fetchMessageThreadForMessage:m updateDatabase:updateDatabase];
        }
    }
    
    [self syncFetchMessageHeaders];
    
    *pNewMessages = newMessages;
}

- (void)syncFetchMessageHeaders {
    NSAssert(_messageHeadersFetched <= _totalMessagesCount, @"invalid messageHeadersFetched");
    
    if(!_loadingFromDB) {
        _serverSyncCount++;
    }
    
    _finishingFetch = YES;
    
    if(_totalMessagesCount == _messageHeadersFetched) {
        SM_LOG_DEBUG(@"all %lu message headers fetched, stopping", _totalMessagesCount);
    } else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
        SM_LOG_DEBUG(@"fetched %lu message headers, stopping", _messageHeadersFetched);
    } else {
        _finishingFetch = NO;
    }
    
    if(_finishingFetch) {
        if(_fetchMessageHeadersOp != nil) {
            [_fetchMessageHeadersOp cancel];
            _fetchMessageHeadersOp = nil;
        }
        
        [self syncFetchMessageThreadsHeaders];
        
        return;
    }
    
    if(_totalMessagesCount != 0) {
        _hadMessages = YES;
    }
    
    if(_loadingFromDB) {
        const NSUInteger numberOfMessagesToFetch = MIN(_totalMessagesCount - _messageHeadersFetched, MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_DB);

        [_dbOps addObject:[[_account database] loadMessageHeadersFromDBFolder:_remoteFolderName offset:_messageHeadersFetched count:numberOfMessagesToFetch getMessagesBlock:^(SMDatabaseOp *op, NSArray<SMOutgoingMessage*> *outgoingMessages, NSArray<MCOIMAPMessage*> *mcoMessages, NSArray<NSString*> *mcoMessagePlainTextBodies, NSArray<NSNumber*> *hasAttachmentsFlags) {
            [_dbOps removeObject:op];
            
            NSAssert(mcoMessagePlainTextBodies == nil || mcoMessagePlainTextBodies.count == mcoMessages.count, @"mcoMessagePlainTextBodies.count %lu, mcoMessages.count %lu", mcoMessagePlainTextBodies.count, mcoMessages.count);

            for(SMOutgoingMessage *message in outgoingMessages) {
                [self addMessage:message externalMessage:NO updateDatabase:NO];
                
                _messageHeadersFetched++;
            }

            NSArray<MCOIMAPMessage*> *newMessages;
            [self syncNewMessages:mcoMessages mcoMessagePlainTextBodies:mcoMessagePlainTextBodies hasAttachmentsFlags:hasAttachmentsFlags updateDatabase:NO newMessages:&newMessages];

            SMMessageBodyFetchQueue *bodyFetchQueue = [self chooseBackgroundOrForegroundMessageBodyFetchQueue];
            
            for(NSUInteger i = 0; i < mcoMessages.count; i++) {
                if((NSNull*)mcoMessagePlainTextBodies[i] == [NSNull null]) {
                    MCOIMAPMessage *m = mcoMessages[i];

                    // TODO: body loading should be cancelled as well as _loadMessageHeadersForUIDsFromDBFolderOp. See issue #72.
                    [bodyFetchQueue fetchMessageBodyWithUID:m.uid messageId:m.gmailMessageID threadId:m.gmailThreadID messageDate:[m.header date] urgent:NO tryLoadFromDatabase:NO remoteFolder:_remoteFolderName localFolder:self];
                }
            }

            SM_LOG_INFO(@"folder %@, outgoing messages loaded: %lu, messages loaded: %lu, headers fetched: %lu", _localName, outgoingMessages.count, mcoMessages.count, _messageHeadersFetched);
            
        }]];
    }
    else {
        const NSUInteger restOfMessages = _totalMessagesCount - _messageHeadersFetched;
        const NSUInteger numberOfMessagesToFetch = MIN(restOfMessages, MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_SERVER);
        const NSUInteger fetchMessagesFromIndex = restOfMessages - numberOfMessagesToFetch + 1;
        
        MCOIndexSet *regionToFetch = [MCOIndexSet indexSetWithRange:MCORangeMake(fetchMessagesFromIndex, numberOfMessagesToFetch - 1)];
        MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
        
        // TODO: handle session reopening/uids validation
        
        NSAssert(session, @"session lost");

        NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
        
        _fetchMessageHeadersOp = [session fetchMessagesByNumberOperationWithFolder:_remoteFolderName requestKind:messageHeadersRequestKind numbers:regionToFetch];
        
        _fetchMessageHeadersOp.urgent = YES;
        
        // TODO: cancellation?
        [_fetchMessageHeadersOp start:^(NSError *error, NSArray<MCOIMAPMessage*> *messages, MCOIndexSet *vanishedMessages) {
            _fetchMessageHeadersOp = nil;
            
            if(error == nil || error.code == MCOErrorNone) {
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                
                // Sort messages asynchronously by sequence number from newest to oldest.
                // Using date would be less efficient, so keep this rough approach.
                dispatch_async(queue, ^{
                    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                    
                    NSArray<MCOIMAPMessage*> *sortedMessages = [messages sortedArrayUsingComparator:[appDelegate.messageComparators messagesComparatorBySequenceNumber]];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSArray<MCOIMAPMessage*> *newMessages;
                        [self syncNewMessages:sortedMessages mcoMessagePlainTextBodies:nil hasAttachmentsFlags:nil updateDatabase:YES newMessages:&newMessages];
                        
                        SMMessageBodyFetchQueue *bodyFetchQueue = [self chooseBackgroundOrForegroundMessageBodyFetchQueue];
                        
                        for(MCOIMAPMessage *m in newMessages) {
                            // TODO: body loading should be cancelled as well as _loadMessageHeadersForUIDsFromDBFolderOp. See issue #72.
                            [bodyFetchQueue fetchMessageBodyWithUID:m.uid messageId:m.gmailMessageID threadId:m.gmailThreadID messageDate:[m.header date] urgent:NO tryLoadFromDatabase:NO remoteFolder:_remoteFolderName localFolder:self];
                        }
                    });
                });
            } else {
                SM_LOG_ERROR(@"Error downloading messages list: %@", error);
            }
        }];
    }
}

- (void)fetchMessageThreadForMessage:(MCOIMAPMessage*)mcoMessage updateDatabase:(BOOL)updateDatabase {
/*
 
 
 TODO
 
 
 uint64_t threadId = mcoMessage.gmailThreadID;
    uint64_t messageId = mcoMessage.gmailMessageID;

    id<SMMailbox> mailbox = [_account mailbox];
    
    NSString *allMailFolder = [mailbox.allMailFolder fullName];
    SMLocalFolder *allMailLocalFolder = allMailFolder? (SMLocalFolder*)[_account.localFolderRegistry getLocalFolderByName:allMailFolder] : (SMLocalFolder*)[NSNull null];
    
    NSString *sentFolder = [mailbox.sentFolder fullName];
    SMLocalFolder *sentLocalFolder = sentFolder? (SMLocalFolder*)[_account.localFolderRegistry getLocalFolderByName:sentFolder] : (SMLocalFolder*)[NSNull null];
    
    for(SMLocalFolder *folderToScan in @[allMailLocalFolder, sentLocalFolder]) {
        if(folderToScan == (SMLocalFolder*)[NSNull null]) {
            continue;
        }
        
        // TODO: accessing a local folder in process of updating doesn't look safe
        SMMessageThread *messageThread = [(SMMessageStorage*)folderToScan.messageStorage messageThreadById:threadId];
        
        if(messageThread == nil || (messageThread.messagesCount == 1 && [messageThread getMessageByMessageId:messageId] != nil)) {
            continue;
        }

        NSString *remoteFolderName = folderToScan.remoteFolderName;
        [_dbOps addObject:[[_account database] loadMessageHeadersForThreadIdFromDBFolder:remoteFolderName threadId:threadId block:^(SMDatabaseOp *op, NSArray<MCOIMAPMessage*> *mcoMessages, NSArray<NSString*> *plainTextBodies, NSArray<NSNumber*> *hasAttachmentsFlags) {
            [_dbOps removeObject:op];
            
            [self loadMessageThread:threadId remoteFolder:remoteFolderName mcoMessages:mcoMessages plainTextBodies:plainTextBodies hasAttachmentsFlags:hasAttachmentsFlags];
            
            NSAssert(_dbMessageThreadsLoadsCount > 0, @"bad _dbMessageThreadsLoadsCount");
            _dbMessageThreadsLoadsCount--;
            
            if(_dbMessageThreadsLoadsCount == 0 && _finishingFetch) {
                // no more threads are loading, and no messages loaded from threads
                // so stop loading headers now and start bodies fetching
                [self finishHeadersSync:updateDatabase];
            }
        }]];
        
        _dbMessageThreadsLoadsCount++;
    }
*/
}

- (Boolean)messageHeadersAreBeingLoaded {
    return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)stopLocalFolderSync:(BOOL)stopBodyLoading {
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
    
    [_messageStorage cancelUpdate];

    for(SMDatabaseOp *dbOp in _dbOps) {
        [dbOp cancel];
    }
    
    [_dbOps removeAllObjects];

    if(stopBodyLoading) {
        [_messageBodyFetchQueue stopBodyFetchQueue];
    }
    
    _dbSyncInProgress = NO;
}

- (void)addMessage:(SMMessage*)message externalMessage:(BOOL)externalMessage updateDatabase:(BOOL)updateUpdate {
    if([_messageStorage addMessageToStorage:message updateDatabase:updateUpdate]) {
        if(externalMessage) {
            _totalMessagesCount++;
        }
        
        [SMNotificationsController localNotifyMessagesUpdated:self updateResult:SMMesssageStorageUpdateResultStructureChanged account:(SMUserAccount*)_account];
    }
}

- (void)addMessage:(SMMessage*)message {
    [self addMessage:message externalMessage:YES updateDatabase:(_kind != SMFolderKindOutbox)];
}

- (void)removeMessage:(SMMessage*)message {
    [_messageStorage removeMessageFromStorage:message updateDatabase:NO];
    
    NSAssert(_totalMessagesCount > 0, @"_totalMessagesCount is 0");
    _totalMessagesCount--;
    
    [SMNotificationsController localNotifyMessagesUpdated:self updateResult:SMMesssageStorageUpdateResultStructureChanged account:(SMUserAccount*)_account];
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
    [SMNotificationsController localNotifyMessageFlagsUpdates:self account:(SMUserAccount*)_account];
    
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

#pragma mark Adding and removing message labels

- (void)addMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label {
    NSAssert(_kind != SMFolderKindOutbox, @"cannot add message labels in the outbox folder");

    // modify the local copy of the message thread
    [messageThread addLabel:label];
    
    for(SMMessage *message in messageThread.messagesSortedByDate) {
        // update the local database
        [[_account database] updateMessageInDBFolder:message.imapMessage folder:_remoteFolderName];
        
        // enqueue the remote folder operation
        SMOpAddLabel *op = [[SMOpAddLabel alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName label:label operationExecutor:[(SMUserAccount*)_account operationExecutor]];
        
        [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    }
}

- (void)removeMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label {
    NSAssert(_kind != SMFolderKindOutbox, @"cannot remove message labels in the outbox folder");
    
    // modify the local copy of the message thread
    [messageThread removeLabel:label];
    
    for(SMMessage *message in messageThread.messagesSortedByDate) {
        // update the local database
        [[_account database] updateMessageInDBFolder:message.imapMessage folder:_remoteFolderName];
        
        // enqueue the remote folder operation
        SMOpRemoveLabel *op = [[SMOpRemoveLabel alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName label:label operationExecutor:[(SMUserAccount*)_account operationExecutor]];
        
        [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    }
    
    if([_remoteFolderName isEqualToString:label]) {
        NSAssert(_kind == SMFolderKindRegular, @"label %@ cannot match a regular folder name", label);
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        
        SMFolder *trashFolder = [appDelegate.currentMailbox trashFolder];
        NSAssert(trashFolder != nil, @"no trash folder");
        
        if(![self moveMessageThread:messageThread toRemoteFolder:trashFolder.fullName]) {
            SM_LOG_WARNING(@"Could not move message thread %lld to trash", messageThread.threadId);
        }
    }
}

#pragma mark Messages movement to other remote folders

- (BOOL)moveMessageThread:(SMMessageThread*)messageThread toRemoteFolder:(NSString*)destRemoteFolderName {
    id<SMMailbox> mailbox = [_account mailbox];
    SMFolder *destFolder = [mailbox getFolderByName:destRemoteFolderName];
    
    if(destFolder == nil) {
        SM_LOG_ERROR(@"Destination folder %@ not found", destRemoteFolderName);
        return FALSE;
    }
    
    if(_kind == SMFolderKindOutbox) {
        if(destFolder.kind != SMFolderKindTrash) {
            SM_LOG_WARNING(@"Destination folder %@ (kind %ld) is not Trash", destRemoteFolderName, destFolder.kind);
            return FALSE;
        }
        
        // There are the following steps that must be done:
        // 1) Cancel message sending from the SMTP queue;
        // 2) Remove the messages from the storage for the outbox folder;
        // 3) Put the deleted messages to the local Trash folder.

        for(SMMessage *message in messageThread.messagesSortedByDate) {
            NSAssert([message isKindOfClass:[SMOutgoingMessage class]], @"non-outgoing message %@ found in Outbox", message);
            [[_account outboxController] cancelMessageSending:(SMOutgoingMessage*)message];

            SMFolder *trashFolder = [[_account mailbox] trashFolder];
            SMLocalFolder *trashLocalFolder = (SMLocalFolder*)[[_account localFolderRegistry] getLocalFolderByName:trashFolder.fullName];

            NSAssert(trashLocalFolder, @"trashLocalFolder is nil");
            [trashLocalFolder addMessage:message];

            [self removeMessage:message];
        }

        [SMNotificationsController localNotifyMessageFlagsUpdates:self account:(SMUserAccount*)_account];
        
        return TRUE;
    }

    // Stop current message loading process.
    // Note that body loading should continue. Body loading errors for messages that aren't there shall be ignored.
    // TODO: check that!
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
    [self stopLocalFolderSync:NO];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
    [[_account messageListController] cancelScheduledMessageListUpdate];

    // Remove the deleted message threads from the message storage.
    NSUInteger *unseenMessagesCountPtr = (_useProvidedUnseenMessagesCount? nil : &_unseenMessagesCount);
    [_messageStorage deleteMessageThread:messageThread updateDatabase:YES unseenMessagesCount:unseenMessagesCountPtr];

    // Now, we have to cancel message bodies loading for the deleted messages.
    MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSet];
    NSArray *messages = [messageThread messagesSortedByDate];
    
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
            [_messageBodyFetchQueue cancelBodyFetchWithUID:message.uid messageId:message.messageId remoteFolder:_remoteFolderName localFolder:self];

            // Delete the message from the local database as well.
            [[_account database] removeMessageFromDBFolder:message.uid folder:_remoteFolderName];
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
    [SMNotificationsController localNotifyMessageFlagsUpdates:self account:(SMUserAccount*)_account];
    
    return TRUE;
}

- (BOOL)moveMessage:(SMMessage*)message withinMessageThread:(SMMessageThread*)messageThread toRemoteFolder:(NSString*)destRemoteFolderName {
    return [self moveMessage:message.messageId uid:message.uid threadId:messageThread.threadId useThreadId:(messageThread? YES : NO) toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint64_t)messageId uid:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName {
    NSNumber *threadIdNum = [_messageStorage messageThreadByMessageId:messageId];

    const uint64_t threadId = (threadIdNum != nil? [threadIdNum unsignedLongLongValue] : 0);
    const Boolean useThreadId = (threadIdNum != nil);

    return [self moveMessage:messageId uid:uid threadId:threadId useThreadId:useThreadId toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint64_t)messageId uid:(uint32_t)uid threadId:(uint64_t)threadId useThreadId:(Boolean)useThreadId toRemoteFolder:(NSString*)destRemoteFolderName {
    NSAssert(![_remoteFolderName isEqualToString:destRemoteFolderName], @"src and dest remove folders are the same %@", _remoteFolderName);

    // Stop current message loading process.
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
    [self stopLocalFolderSync:NO];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
    [[_account messageListController] cancelScheduledMessageListUpdate];

    // Remove the deleted message from the current folder in the message storage.
    // This is necessary to immediately reflect the visual change.
    Boolean needUpdateMessageList = NO;
    
    if(useThreadId) {
        NSUInteger *unseenMessagesCountPtr = (_useProvidedUnseenMessagesCount? nil : &_unseenMessagesCount);

        needUpdateMessageList = [_messageStorage deleteMessageFromStorage:uid threadId:threadId remoteFolder:_remoteFolderName unseenMessagesCount:unseenMessagesCountPtr];

        // Notify observers that message flags have possibly changed.
        [SMNotificationsController localNotifyMessageFlagsUpdates:self account:(SMUserAccount*)_account];
    }
    else {
        // TODO: Should we adjust folder stats (unseen count)?
    }
    
    // Now, we have to cancel message bodies loading for the deleted messages.
    MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSetWithIndex:uid];
    
    // Cancel message body fetching.
    [_messageBodyFetchQueue cancelBodyFetchWithUID:uid messageId:messageId remoteFolder:_remoteFolderName localFolder:self];

    // Delete the message from the local database.
    [[_account database] removeMessageFromDBFolder:uid folder:_remoteFolderName];

    // After the local storage is cleared and there is no bodies loading,
    // actually move the messages on the server.
    SMOpMoveMessages *op = [[SMOpMoveMessages alloc] initWithUids:messagesToMoveUids srcRemoteFolderName:_remoteFolderName dstRemoteFolderName:destRemoteFolderName operationExecutor:[(SMUserAccount*)_account operationExecutor]];
    
    [[(SMUserAccount*)_account operationExecutor] enqueueOperation:op];
    
    return needUpdateMessageList;
}

@end
