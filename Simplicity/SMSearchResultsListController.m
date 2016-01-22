//
//  SMSearchResultsListController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMSearchDescriptor.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMSearchResultsListViewController.h"
#import "SMSearchResultsListController.h"
#import "SMSectionMenuViewController.h"

const char *const mcoOpKinds[] = {
    "MCOIMAPSearchKindAll",
    "MCOIMAPSearchKindNone",
    "MCOIMAPSearchKindFrom",
    "MCOIMAPSearchKindTo",
    "MCOIMAPSearchKindCc",
    "MCOIMAPSearchKindBcc",
    "MCOIMAPSearchKindRecipient",
    "MCOIMAPSearchKindSubject",
    "MCOIMAPSearchKindContent",
    "MCOIMAPSearchKindBody",
    "MCOIMAPSearchKindUids",
    "MCOIMAPSearchKindHeader",
    "MCOIMAPSearchKindRead",
    "MCOIMAPSearchKindUnread",
    "MCOIMAPSearchKindFlagged",
    "MCOIMAPSearchKindUnflagged",
    "MCOIMAPSearchKindAnswered",
    "MCOIMAPSearchKindUnanswered",
    "MCOIMAPSearchKindDraft",
    "MCOIMAPSearchKindUndraft",
    "MCOIMAPSearchKindDeleted",
    "MCOIMAPSearchKindSpam",
    "MCOIMAPSearchKindBeforeDate",
    "MCOIMAPSearchKindOnDate",
    "MCOIMAPSearchKindSinceDate",
    "MCOIMAPSearchKindBeforeReceivedDate",
    "MCOIMAPSearchKindOnReceivedDate",
    "MCOIMAPSearchKindSinceReceivedDate",
    "MCOIMAPSearchKindSizeLarger",
    "MCOIMAPSearchKindSizeSmaller",
    "MCOIMAPSearchGmailThreadID",
    "MCOIMAPSearchGmailMessageID",
    "MCOIMAPSearchGmailRaw",
    "MCOIMAPSearchKindOr",
    "MCOIMAPSearchKindAnd",
    "MCOIMAPSearchKindNot",
};

@interface SearchOpInfo : NSObject
@property (readonly) MCOIMAPSearchKind kind; // TODO: create our own type
@property (readonly) MCOIMAPSearchOperation *op;
@property MCOIndexSet *uids;
@end

@implementation SearchOpInfo

- (id)initWithOp:(MCOIMAPSearchOperation*)op kind:(MCOIMAPSearchKind)kind {
    self = [super init];
    
    if(self) {
        _op = op;
        _kind = kind;
    }
    
    return self;
}

@end

@implementation SMSearchResultsListController {
    NSUInteger _searchId;
    NSString *_searchString;
    NSMutableDictionary *_searchResults;
    NSMutableArray *_searchResultsFolderNames;
    NSMutableArray<SearchOpInfo*> *_searchOps;
    NSUInteger _completedOps;
    Boolean _shouldClearSearchResults;
}

- (id)init {
    self = [super init];
    
    if(self != nil) {
        _searchResults = [[NSMutableDictionary alloc] init];
        _searchResultsFolderNames = [[NSMutableArray alloc] init];
        _searchOps = [NSMutableArray array];
        _completedOps = 0;
    }
    
    return self;
}

- (void)clearPreviousSearch {
    for(SearchOpInfo *opInfo in _searchOps) {
        [opInfo.op cancel];
    }
    
    [_searchOps removeAllObjects];
    _completedOps = 0;

    _subjectSearchResults = [MCOIndexSet indexSet];
    _contactSearchResults = [MCOIndexSet indexSet];
}

- (void)startNewSearch:(NSString*)searchString exitingLocalFolder:(NSString*)existingLocalFolder {
    SM_LOG_DEBUG(@"searching for string '%@'", searchString);
    
    _searchString = searchString;
    _shouldClearSearchResults = YES;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    
    NSAssert(session, @"session is nil");
    
    NSString *remoteFolderName = nil;
    NSString *searchResultsLocalFolder = nil;
    SMSearchDescriptor *searchDescriptor = nil;
    
    if(existingLocalFolder == nil) {
        // TODO: handle search in search results differently

        NSString *allMailFolder = [[[[appDelegate model] mailbox] allMailFolder] fullName];
        if(allMailFolder != nil) {
            SM_LOG_DEBUG(@"searching in all mail");
            remoteFolderName = allMailFolder;
        } else {
            NSAssert(nil, @"no all mail folder, revise this logic!");

            // TODO: will require another logic for non-gmail accounts
            remoteFolderName = [[[[appDelegate model] messageListController] currentLocalFolder] localName];
        }
        
        // TODO: introduce search results descriptor to avoid this funny folder name
        searchResultsLocalFolder = [NSString stringWithFormat:@"//search_results//%lu", _searchId++];
        
        NSAssert(searchResultsLocalFolder != nil, @"folder name couldn't be generated");
        NSAssert([_searchResults objectForKey:searchResultsLocalFolder] == nil, @"duplicated generated folder name");
        
        if([[[appDelegate model] localFolderRegistry] createLocalFolder:searchResultsLocalFolder remoteFolder:remoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO] == nil) {
            NSAssert(false, @"could not create local folder for search results");
        }
        
        searchDescriptor = [[SMSearchDescriptor alloc] init:searchString localFolder:searchResultsLocalFolder remoteFolder:remoteFolderName];

        [_searchResults setObject:searchDescriptor forKey:searchResultsLocalFolder];
        [_searchResultsFolderNames addObject:searchResultsLocalFolder];
    } else {
        searchResultsLocalFolder = existingLocalFolder;

        searchDescriptor = [_searchResults objectForKey:existingLocalFolder];
        NSAssert(searchDescriptor != nil, @"no search descriptor for existing search results");
    
        NSInteger index = [self getSearchIndex:searchResultsLocalFolder];
        NSAssert(index >= 0, @"no index for existing search results folder");

        remoteFolderName = [searchDescriptor remoteFolder];
        NSAssert(searchDescriptor != nil, @"no search descriptor found for exiting local folder");
        
        [searchDescriptor clearState];
    }

    [[[appDelegate appController] searchResultsListViewController] reloadData];
    
    [self clearPreviousSearch];
    
    MCOIMAPSearchKind kinds[] = {
        MCOIMAPSearchKindFrom,
        MCOIMAPSearchKindTo,
        MCOIMAPSearchKindCc,
        MCOIMAPSearchKindSubject};
    
    for(int i = 0; i < sizeof(kinds)/sizeof(kinds[0]); i++) {
        MCOIMAPSearchKind kind = kinds[i];
        MCOIMAPSearchOperation *op = [session searchOperationWithFolder:remoteFolderName kind:kind searchString:searchString];
        op.urgent = YES;
        
        [op start:^(NSError *error, MCOIndexSet *uids) {
            SearchOpInfo *opInfo = _searchOps[i];
            
            if(error == nil) {
                opInfo.uids = uids;
            } else {
                SM_LOG_ERROR(@"search in remote folder %@ failed, error %@", remoteFolderName, error);
                
                opInfo.uids = [MCOIndexSet indexSet];
            }
            
            SM_LOG_INFO(@"search kind %s: %u messages found in remote folder %@", mcoOpKinds[opInfo.kind], opInfo.uids.count, remoteFolderName);
            
            [self updatePopulatedSearchResults:opInfo.uids kind:kind];
            
            _completedOps++;
            
            if(_completedOps == _searchOps.count) {
                MCOIndexSet *searchResults = [MCOIndexSet indexSet];
                for(SearchOpInfo *opInfo in _searchOps) {
                    [searchResults addIndexSet:opInfo.uids];
                }
                
                SM_LOG_INFO(@"%u messages found in remote folder %@, loading to local folder %@", searchResults.count, remoteFolderName, searchResultsLocalFolder);
                
                searchDescriptor.messagesLoadingStarted = YES;
                
                [[[appDelegate model] messageListController] loadSearchResults:searchResults remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:searchResultsLocalFolder];
                
                [[[appDelegate appController] searchResultsListViewController] selectSearchResult:searchResultsLocalFolder];
                [[[appDelegate appController] searchResultsListViewController] reloadData];
            }
        }];

        [_searchOps addObject:[[SearchOpInfo alloc] initWithOp:op kind:kind]];
    }
}

- (void)updatePopulatedSearchResults:(MCOIndexSet*)uids kind:(MCOIMAPSearchKind)kind {
    switch(kind) {
        case MCOIMAPSearchKindFrom:
        case MCOIMAPSearchKindTo:
        case MCOIMAPSearchKindCc:
            [_contactSearchResults addIndexSet:uids];
            break;
            
        case MCOIMAPSearchKindSubject:
            [_subjectSearchResults addIndexSet:uids];
            break;
            
        default:
            NSAssert(nil, @"Unexpected kind %ld", (long)kind);
            break;
    }
}

- (NSInteger)getSearchIndex:(NSString*)searchResultsLocalFolder {
    for(NSInteger i = 0; i < _searchResultsFolderNames.count; i++) {
        if([_searchResultsFolderNames[i] isEqualToString:searchResultsLocalFolder])
            return i;
    }
    
    return -1;
}

- (NSUInteger)searchResultsCount {
    return [_searchResults count];
}

- (SMSearchDescriptor*)getSearchResults:(NSUInteger)index {
    return [_searchResults objectForKey:[_searchResultsFolderNames objectAtIndex:index]];
}

- (void)searchHasFailed:(NSString*)searchResultsLocalFolder {
    SMSearchDescriptor *searchDescriptor = [_searchResults objectForKey:searchResultsLocalFolder];
    searchDescriptor.searchFailed = true;
}

- (void)removeSearch:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);

    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");

    [_searchResults removeObjectForKey:[_searchResultsFolderNames objectAtIndex:index]];
    [_searchResultsFolderNames removeObjectAtIndex:index];
}

- (void)reloadSearch:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);

    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    NSAssert(searchDescriptor != nil, @"search descriptor not found");

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolder *localFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:searchDescriptor.localFolder];
    
    [localFolder clearMessages];

    Boolean preserveSelection = NO;
    [[[appDelegate appController] messageListViewController] reloadMessageList:preserveSelection];

    [self startNewSearch:searchDescriptor.searchPattern exitingLocalFolder:localFolder.localName];
}

- (void)stopSearch:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);

    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");

    // stop search op itself, if any
    [self clearPreviousSearch];

    // stop message list loading, if anys
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    NSAssert(searchDescriptor != nil, @"search descriptor not found");

    SMLocalFolder *localFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:searchDescriptor.localFolder];
    [localFolder stopMessagesLoading:NO];
    
    searchDescriptor.searchStopped = true;

    // TODO: stop message bodies loading?
}

- (Boolean)searchStopped:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);
    
    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    // stop message list loading, if anys
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    
    return searchDescriptor.searchStopped;
}

- (void)updateSearchImapMessages:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    if(_shouldClearSearchResults) {
        [[[appDelegate appController] searchMenuViewController] clearAllItems];
        
        _shouldClearSearchResults = NO;
    }
    
    if(_subjectSearchResults.count > 0) {
        NSString *section = @"Subjects";
        
        [[[appDelegate appController] searchMenuViewController] addSection:section];

        NSMutableOrderedSet *subjects = [NSMutableOrderedSet orderedSet];

        for(MCOIMAPMessage *imapMessage in imapMessages) {
            if([_subjectSearchResults containsIndex:imapMessage.uid]) {
                NSString *subject = imapMessage.header.subject;
                
                [subjects addObject:subject];
            }
        }

        NSArray *sortedSubjects = [subjects sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
            return [str1 compare:str2];
        }];
        
        for(NSString *subject in sortedSubjects) {
            if(subject != nil) {
                [[[appDelegate appController] searchMenuViewController] addItem:subject section:section target:nil action:nil];
            }
        }
    }

    if(_contactSearchResults.count > 0) {
        NSString *section = @"Contacts";

        [[[appDelegate appController] searchMenuViewController] addSection:section];
        
        NSMutableOrderedSet *contacts = [NSMutableOrderedSet orderedSet];
        
        for(MCOIMAPMessage *imapMessage in imapMessages) {
            for(MCOAddress *address in imapMessage.header.to) {
                NSString *rfc822Address = address.nonEncodedRFC822String;
                
                if([[rfc822Address lowercaseString] containsString:[_searchString lowercaseString]]) {
                    [contacts addObject:rfc822Address];
                }
            }
        }

        NSArray *sortedContacts = [contacts sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
            return [str1 compare:str2];
        }];
        
        for(NSString *contact in sortedContacts) {
            [[[appDelegate appController] searchMenuViewController] addItem:contact section:section target:nil action:nil];
        }
    }

    [[[appDelegate appController] searchMenuViewController] reloadItems];
}

@end
