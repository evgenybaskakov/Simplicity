//
//  SMSearchFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/16/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageStorage.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOpMoveMessages.h"
#import "SMOpDeleteMessages.h"
#import "SMOpSetMessageFlags.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMessageThread.h"
#import "SMMessageThreadDescriptor.h"
#import "SMMessageThreadDescriptorEntry.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMailbox.h"
#import "SMDatabase.h"
#import "SMOutboxController.h"
#import "SMNotificationsController.h"
#import "SMAddress.h"
#import "SMFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolderMessageBodyFetchQueue.h"
#import "SMLocalFolder.h"
#import "SMSearchFolder.h"

@implementation SMSearchFolder {
    MCOIndexSet *_allSelectedMessageUIDsToLoad;
    MCOIndexSet *_restOfSelectedMessageUIDsToLoad;
}

- (id)initWithLocalFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName {
    self = [super initWithLocalFolderName:localFolderName remoteFolderName:remoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO];
    
    return self;
}

- (void)startLocalFolderSync {
    if(_dbSyncInProgress || _folderInfoOp != nil || _fetchMessageHeadersOp != nil || _searchMessageThreadsOps.count > 0 || _fetchMessageThreadsHeadersOps.count > 0) {
        SM_LOG_WARNING(@"previous op is still in progress for folder %@", _localName);
        return;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] localFolderRegistry] keepFoldersMemoryLimit];
    
    [self loadSelectedMessagesInternal];
}

- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs updateResults:(BOOL)updateResults {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] localFolderRegistry] keepFoldersMemoryLimit];
    
    if(updateResults) {
        NSAssert(_allSelectedMessageUIDsToLoad.count > 0, @"no active selected message loading");
        
        BOOL loadingFinished = (_restOfSelectedMessageUIDsToLoad.count == 0);
        if(loadingFinished) {
            NSAssert(nil, @"TODO");
        }
        else {
            MCOIndexSet *newMessageUIDs = messageUIDs;
            [newMessageUIDs removeIndexSet:_allSelectedMessageUIDsToLoad];
            
            [_restOfSelectedMessageUIDsToLoad addIndexSet:newMessageUIDs];
            [_allSelectedMessageUIDsToLoad addIndexSet:newMessageUIDs];

            SM_LOG_INFO(@"updating existing message loading: %u new messages (_allSelectedMessageUIDsToLoad %u, _restOfSelectedMessageUIDsToLoad %u)", newMessageUIDs.count, _allSelectedMessageUIDsToLoad.count, _restOfSelectedMessageUIDsToLoad.count);
            
            _totalMessagesCount += newMessageUIDs.count;
        }
    }
    else {
        _messageHeadersFetched = 0;
        
        [_messageStorage startUpdate:_localName];
        
        _allSelectedMessageUIDsToLoad = messageUIDs;
        _restOfSelectedMessageUIDsToLoad = messageUIDs;
        
        _totalMessagesCount = _restOfSelectedMessageUIDsToLoad.count;
        
        [self loadSelectedMessagesInternal];
    }
}

- (void)loadSelectedMessagesInternal {
    if(_remoteFolderName == nil) {
        SM_LOG_WARNING(@"remote folder for %@ is not set", _localName);
        return;
    }
    
    if(_restOfSelectedMessageUIDsToLoad == nil) {
        SM_LOG_WARNING(@"no message uids to load in folder %@", _localName);
        return;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    
    NSAssert(session, @"session lost");
    
    BOOL finishFetch = YES;
    
    if(_totalMessagesCount == _messageHeadersFetched) {
        SM_LOG_DEBUG(@"all %lu message headers fetched, stopping", _totalMessagesCount);
    } else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
        SM_LOG_DEBUG(@"fetched %lu message headers, stopping", _messageHeadersFetched);
    } else if(_restOfSelectedMessageUIDsToLoad.count > 0) {
        finishFetch = NO;
    }
    
    if(finishFetch) {
        [_messageStorage endUpdate:_localName removeFolder:nil removeVanishedMessages:NO updateDatabase:NO unseenMessagesCount:&_unseenMessagesCount processNewUnseenMessagesBlock:nil];
        
        [self finishMessageHeadersFetching];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObject:_localName forKey:@"LocalFolderName"]];
        
        return;
    }
    
    MCOIndexSet *const messageUIDsToLoadNow = [MCOIndexSet indexSet];
    MCORange *const ranges = [_restOfSelectedMessageUIDsToLoad allRanges];
    
    for(unsigned int i = [_restOfSelectedMessageUIDsToLoad rangesCount]; i > 0; i--) {
        const MCORange currentRange = ranges[i-1];
        const NSUInteger len = MCORangeRightBound(currentRange) - MCORangeLeftBound(currentRange) + 1;
        const NSUInteger maxCountToLoad = MESSAGE_HEADERS_TO_FETCH_AT_ONCE - messageUIDsToLoadNow.count;
        
        if(len < maxCountToLoad) {
            [messageUIDsToLoadNow addRange:currentRange];
        } else {
            // note: "- 1" is because zero length means one element range
            const MCORange range = MCORangeMake(MCORangeRightBound(currentRange) - maxCountToLoad + 1, maxCountToLoad - 1);
            
            [messageUIDsToLoadNow addRange:range];
            
            break;
        }
    }
    
    SM_LOG_DEBUG(@"loading %u of %u search results...", messageUIDsToLoadNow.count, _restOfSelectedMessageUIDsToLoad.count);
    
    NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
    
    _fetchMessageHeadersOp = [session fetchMessagesOperationWithFolder:_remoteFolderName requestKind:messageHeadersRequestKind uids:messageUIDsToLoadNow];
    
    _fetchMessageHeadersOp.urgent = YES;
    
    [_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
        _fetchMessageHeadersOp = nil;
        
        if(error == nil) {
            SM_LOG_DEBUG(@"loaded %lu message headers...", messages.count);
            
            [_restOfSelectedMessageUIDsToLoad removeIndexSet:messageUIDsToLoadNow];
            
            _messageHeadersFetched += [messages count];
            
            [self updateMessages:messages remoteFolder:_remoteFolderName updateDatabase:NO];
            
            [self loadSelectedMessagesInternal];
        } else {
            SM_LOG_ERROR(@"Error downloading search results: %@", error);
        }
    }];
}

@end
