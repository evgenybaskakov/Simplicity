//
//  SMSearchLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMAbstractAccount.h"
#import "SMUserAccount.h"
#import "SMMessageStorage.h"
#import "SMAppController.h"
#import "SMNotificationsController.h"
#import "SMOperationExecutor.h"
#import "SMOpMoveMessages.h"
#import "SMOpDeleteMessages.h"
#import "SMOpSetMessageFlags.h"
#import "SMMessageListController.h"
#import "SMAccountSearchController.h"
#import "SMMessageThread.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMailbox.h"
#import "SMDatabase.h"
#import "SMOutboxController.h"
#import "SMNotificationsController.h"
#import "SMAddress.h"
#import "SMFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageBodyFetchQueue.h"
#import "SMLocalFolder.h"
#import "SMSearchLocalFolder.h"
#import "SMMessageComparators.h"

@implementation SMSearchLocalFolder {
    MCOIndexSet *_allSelectedMessageUIDsToLoad;
    MCOIndexSet *_restOfSelectedMessageUIDsToLoadFromDB;
    MCOIndexSet *_restOfSelectedMessageUIDsToLoadFromServer;
    SMDatabaseOp *_loadMessageHeadersForUIDsFromDBFolderOp;
    NSUInteger _currentSearchId;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName {
    self = [super initWithUserAccount:account localFolderName:localFolderName remoteFolderName:remoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO];
    
    return self;
}

- (BOOL)folderStillLoadingInitialState {
    return NO;
}

- (void)startLocalFolderSync {
    if(_dbSyncInProgress || _folderInfoOp != nil || _fetchMessageHeadersOp != nil || _searchMessageThreadsOps.count > 0) {
        SM_LOG_WARNING(@"previous op is still in progress for folder %@", _localName);
        return;
    }
    
    [self loadSelectedMessagesInternal];
}

- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs updateResults:(BOOL)updateResults {
    if(updateResults) {
        BOOL loadingFinished = (_restOfSelectedMessageUIDsToLoadFromDB.count == 0 && _restOfSelectedMessageUIDsToLoadFromServer.count == 0);

        MCOIndexSet *newMessageUIDs = messageUIDs;
        [newMessageUIDs removeIndexSet:_allSelectedMessageUIDsToLoad];
        
        [_allSelectedMessageUIDsToLoad addIndexSet:newMessageUIDs];
        [_restOfSelectedMessageUIDsToLoadFromDB addIndexSet:newMessageUIDs];
        [_restOfSelectedMessageUIDsToLoadFromServer addIndexSet:newMessageUIDs];

        SM_LOG_INFO(@"updating existing message loading: %u new messages (_allSelectedMessageUIDsToLoad %u, _restOfSelectedMessageUIDsToLoadFromDB %u, _restOfSelectedMessageUIDsToLoadFromServer %u)", newMessageUIDs.count, _allSelectedMessageUIDsToLoad.count, _restOfSelectedMessageUIDsToLoadFromDB.count, _restOfSelectedMessageUIDsToLoadFromServer.count);
        
        _totalMessagesCount += newMessageUIDs.count;

        if(loadingFinished) {
            // Restart fetching the updated rest of messages.
            // Don't invalidate existing messages.
            [_messageStorage startUpdate];
            
            [self loadSelectedMessagesInternal];
            
            SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
            [[appDelegate appController] finishSearch:SMSearchOperationKind_Content];
        }
    }
    else {
        _messageHeadersFetched = 0;
        
        _allSelectedMessageUIDsToLoad = [MCOIndexSet indexSet];
        [_allSelectedMessageUIDsToLoad addIndexSet:messageUIDs];
        
        _restOfSelectedMessageUIDsToLoadFromDB = [MCOIndexSet indexSet];
        [_restOfSelectedMessageUIDsToLoadFromDB addIndexSet:messageUIDs];
        
        _restOfSelectedMessageUIDsToLoadFromServer = [MCOIndexSet indexSet];
        [_restOfSelectedMessageUIDsToLoadFromServer addIndexSet:messageUIDs];

        _totalMessagesCount = _allSelectedMessageUIDsToLoad.count;
        
        [_messageStorage startUpdate];
        
        [self loadSelectedMessagesInternal];
    }
}

- (void)loadSelectedMessagesInternal {
    if(_remoteFolderName == nil) {
        SM_LOG_WARNING(@"remote folder for %@ is not set", _localName);
        return;
    }
    
    if(_allSelectedMessageUIDsToLoad == nil) {
        SM_LOG_WARNING(@"no message uids to load in folder %@", _localName);
        return;
    }
    
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    
    NSAssert(session, @"session lost");
    
    BOOL finishFetch = YES;
    
    if(_totalMessagesCount == _messageHeadersFetched) {
        SM_LOG_DEBUG(@"all %lu message headers fetched, stopping", _totalMessagesCount);
    } else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
        SM_LOG_DEBUG(@"fetched %lu message headers, stopping", _messageHeadersFetched);
    } else if(_restOfSelectedMessageUIDsToLoadFromDB.count > 0 || _restOfSelectedMessageUIDsToLoadFromServer.count > 0) {
        finishFetch = NO;
    }
    
    if(finishFetch) {
        SMMessageStorageUpdateResult updateResult = [_messageStorage endUpdateWithRemoteFolder:nil removeVanishedMessages:NO updateDatabase:NO unseenMessagesCount:&_unseenMessagesCount processNewUnseenMessagesBlock:nil];
        
        [self finalizeLocalFolderUpdate:updateResult];
        
        return;
    }
    
    BOOL loadFromDB = (_restOfSelectedMessageUIDsToLoadFromDB.count > 0? YES : NO);
    MCOIndexSet *const restOfMessages = loadFromDB? _restOfSelectedMessageUIDsToLoadFromDB : _restOfSelectedMessageUIDsToLoadFromServer;
    
    MCOIndexSet *const messageUIDsToLoadNow = [MCOIndexSet indexSet];
    MCORange *const ranges = [restOfMessages allRanges];
    
    for(unsigned int i = [restOfMessages rangesCount]; i > 0; i--) {
        const MCORange currentRange = ranges[i-1];
        const NSUInteger len = MCORangeRightBound(currentRange) - MCORangeLeftBound(currentRange) + 1;
        const NSUInteger maxCountToLoad = (loadFromDB? MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_DB : MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_SERVER) - messageUIDsToLoadNow.count;
        
        if(len < maxCountToLoad) {
            [messageUIDsToLoadNow addRange:currentRange];
        } else {
            // note: "- 1" is because zero length means one element range
            const MCORange range = MCORangeMake(MCORangeRightBound(currentRange) - maxCountToLoad + 1, maxCountToLoad - 1);
            
            [messageUIDsToLoadNow addRange:range];
            
            break;
        }
    }
    
    NSUInteger searchId = ++_currentSearchId;
    
    if(loadFromDB) {
        SM_LOG_DEBUG(@"loading %u of %u search results from database", messageUIDsToLoadNow.count, restOfMessages.count);
        
        if(_loadMessageHeadersForUIDsFromDBFolderOp != nil) {
            [_loadMessageHeadersForUIDsFromDBFolderOp cancel];
            _loadMessageHeadersForUIDsFromDBFolderOp = nil;
        }
        
        SMSearchLocalFolder __weak *weakSelf = self;
        _loadMessageHeadersForUIDsFromDBFolderOp = [[_account database] loadMessageHeadersForUIDsFromDBFolder:_remoteFolderName uids:messageUIDsToLoadNow block:^(SMDatabaseOp *op, NSArray<MCOIMAPMessage*> *messages, NSArray<NSString*> *plainTextBodies, NSArray<NSNumber*> *hasAttachmentsFlags) {
            SMSearchLocalFolder *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }

            if(searchId != _self->_currentSearchId) {
                SM_LOG_INFO(@"stale DB search dropped (stale search id %lu, current search id %lu)", searchId, _self->_currentSearchId);
                return;
            }

            [_self->_restOfSelectedMessageUIDsToLoadFromDB removeIndexSet:messageUIDsToLoadNow];
            
            // Reduce the SERVER set of messages to load by the set of messages actually loaded from DB.
            for(MCOIMAPMessage *m in messages) {
                [_self->_restOfSelectedMessageUIDsToLoadFromServer removeIndex:m.uid];
            }

            [_self completeMessagesRegionLoading:messages plainTextBodies:plainTextBodies hasAttachmentsFlags:hasAttachmentsFlags messageUIDsRequestedToLoad:messageUIDsToLoadNow updateDatabase:NO];
        }];
    }
    else {
        SM_LOG_DEBUG(@"loading %u of %u search results from server", messageUIDsToLoadNow.count, restOfMessages.count);

        NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
        
        _fetchMessageHeadersOp = [session fetchMessagesOperationWithFolder:_remoteFolderName requestKind:messageHeadersRequestKind uids:messageUIDsToLoadNow];
        
        _fetchMessageHeadersOp.urgent = YES;
        
        SMSearchLocalFolder __weak *weakSelf = self;
        [_fetchMessageHeadersOp start:^(NSError *error, NSArray<MCOIMAPMessage*> *messages, MCOIndexSet *vanishedMessages) {
            SMSearchLocalFolder *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            if(error == nil || error.code == MCOErrorNone) {
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                
                // Sort messages asynchronously by sequence number from newest to oldest.
                // Using date would be less efficient, so keep this rough approach.
                dispatch_async(queue, ^{
                    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
                    
                    NSArray<MCOIMAPMessage*> *sortedMessages = [messages sortedArrayUsingComparator:[appDelegate.messageComparators messagesComparatorBySequenceNumber]];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(searchId != _self->_currentSearchId) {
                            SM_LOG_INFO(@"stale SERVER search dropped (stale search id %lu, current search id %lu)", searchId, _self->_currentSearchId);
                            return;
                        }
                        
                        _self->_fetchMessageHeadersOp = nil;
                        
                        [_self->_restOfSelectedMessageUIDsToLoadFromServer removeIndexSet:messageUIDsToLoadNow];
                        
                        // Reduce the DB set of messages to load by the set of messages actually loaded from SERVER.
                        for(MCOIMAPMessage *m in sortedMessages) {
                            [_self->_restOfSelectedMessageUIDsToLoadFromDB removeIndex:m.uid];
                        }
                        
                        [_self completeMessagesRegionLoading:sortedMessages plainTextBodies:nil hasAttachmentsFlags:nil messageUIDsRequestedToLoad:messageUIDsToLoadNow updateDatabase:YES];
                    });
                });
            }
            else {
                SM_LOG_ERROR(@"Error downloading search results: %@", error);
            }
        }];
    }
}

- (void)completeMessagesRegionLoading:(NSArray<MCOIMAPMessage*>*)mcoMessages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags messageUIDsRequestedToLoad:(MCOIndexSet*)messageUIDsToLoadNow updateDatabase:(BOOL)updateDatabase {
    SM_LOG_DEBUG(@"loaded %lu message headers...", mcoMessages.count);
    
    _messageHeadersFetched += mcoMessages.count;
    
    // Store found messages in the DB 
    [self updateMessageHeaders:mcoMessages plainTextBodies:plainTextBodies hasAttachmentsFlags:hasAttachmentsFlags updateDatabase:updateDatabase newMessages:nil];
    [self loadSelectedMessagesInternal];
    
    for(NSUInteger i = 0; i < mcoMessages.count; i++) {
        if(plainTextBodies == nil || (NSNull*)plainTextBodies[i] == [NSNull null]) {
            MCOIMAPMessage *m = mcoMessages[i];
            
            // TODO: body loading should be cancelled as well as _loadMessageHeadersForUIDsFromDBFolderOp. See issue #72.
            [_messageBodyFetchQueue fetchMessageBodyWithUID:m.uid messageId:m.gmailMessageID threadId:m.gmailThreadID messageDate:[m.header date] urgent:NO tryLoadFromDatabase:YES remoteFolder:_remoteFolderName localFolder:self];
        }
    }
}

- (void)stopLocalFolderSync {
    _currentSearchId++;

    if(_loadMessageHeadersForUIDsFromDBFolderOp != nil) {
        [_loadMessageHeadersForUIDsFromDBFolderOp cancel];
        _loadMessageHeadersForUIDsFromDBFolderOp = nil;
    }
    
    _allSelectedMessageUIDsToLoad = nil;
    _restOfSelectedMessageUIDsToLoadFromDB = nil;
    _restOfSelectedMessageUIDsToLoadFromServer = nil;

    [super stopLocalFolderSync:YES];
}

@end
