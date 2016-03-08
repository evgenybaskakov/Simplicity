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
#import "SMDatabase.h"
#import "SMStringUtils.h"
#import "SMAddress.h"
#import "SMSearchToken.h"
#import "SMSearchDescriptor.h"
#import "SMTextMessage.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMSearchResultsListController.h"
#import "SMSectionMenuViewController.h"
#import "SMTokenFieldViewController.h"
#import "SMTokenView.h"

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
@property (readonly) SearchExpressionKind kind;
@property MCOIMAPBaseOperation *op;
@end

@implementation SearchOpInfo
- (id)initWithOp:(MCOIMAPSearchOperation*)op kind:(SearchExpressionKind)kind {
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
    NSString *_originalSearchString;
    NSMutableArray<SMSearchToken*> *_searchTokens;
    NSString *_mainSearchPart;
    NSMutableDictionary *_searchResults;
    NSMutableArray *_searchResultsFolderNames;
    NSMutableArray<SearchOpInfo*> *_suggestionSearchOps;
    NSUInteger _completedSuggestionSearchOps;
    SearchOpInfo *_mainSearchOp;
    NSMutableOrderedSet *_suggestionResultsSubjects;
    NSMutableOrderedSet *_suggestionResultsContacts;
    MCOIndexSet *_searchMessagesUIDs;
    SMTokenView *_tokenViewWithMenu;
    NSUInteger _currentSearchId;
    NSString *_searchRemoteFolderName;
    NSString *_searchResultsLocalFolderName;
    NSMutableArray<SMDatabaseOp*> *_dbOps;
}

- (id)init {
    self = [super init];
    
    if(self != nil) {
        _searchResults = [[NSMutableDictionary alloc] init];
        _searchResultsFolderNames = [[NSMutableArray alloc] init];
        _suggestionSearchOps = [NSMutableArray array];
        _suggestionResultsSubjects = [NSMutableOrderedSet orderedSet];
        _suggestionResultsContacts = [NSMutableOrderedSet orderedSet];
        _dbOps = [NSMutableArray array];
    }
    
    return self;
}

- (void)clearPreviousSearch {
    for(SearchOpInfo *opInfo in _suggestionSearchOps) {
        [opInfo.op cancel];
    }
    
    for(SMDatabaseOp *dbOp in _dbOps) {
        [dbOp cancel];
    }
    
    [_dbOps removeAllObjects];

    [_mainSearchOp.op cancel];
    
    [_suggestionSearchOps removeAllObjects];
    _mainSearchOp = nil;
    
    _subjectSearchResults = [MCOIndexSet indexSet];
    _contactSearchResults = [MCOIndexSet indexSet];
    
    _suggestionResultsSubjects = [NSMutableOrderedSet orderedSet];
    _suggestionResultsContacts = [NSMutableOrderedSet orderedSet];
    
    _searchMessagesUIDs = nil;
    
    _currentSearchId++;
}

- (BOOL)startNewSearch:(NSString*)searchString {
    searchString = [SMStringUtils trimString:searchString];
    SM_LOG_INFO(@"searching for string '%@'", searchString);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    _searchTokens = [[[[appDelegate appController] searchFieldViewController] representedTokenObjects] mutableCopy];

    if(searchString.length != 0) {
        _mainSearchPart = searchString;
    }
    else {
        _mainSearchPart = nil;
    }
    
    NSAssert(_searchTokens.count != 0 || _mainSearchPart != nil, @"no search tokens");
    
    _originalSearchString = searchString;
    
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    
    NSAssert(session, @"session is nil");
    
    if(_searchResultsLocalFolderName == nil) {
        // TODO: handle search in search results differently
        NSString *remoteFolderName = nil;
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
        NSString *searchResultsLocalFolder = [NSString stringWithFormat:@"//search_results//%lu", _searchId++];
        
        NSAssert(searchResultsLocalFolder != nil, @"folder name couldn't be generated");
        NSAssert([_searchResults objectForKey:searchResultsLocalFolder] == nil, @"duplicated generated folder name");
        
        if([[[appDelegate model] localFolderRegistry] createLocalFolder:searchResultsLocalFolder remoteFolder:remoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO] == nil) {
            NSAssert(false, @"could not create local folder for search results");
        }
        
        SMSearchDescriptor *searchDescriptor = [[SMSearchDescriptor alloc] init:searchString localFolder:searchResultsLocalFolder remoteFolder:remoteFolderName];
        
        [_searchResults setObject:searchDescriptor forKey:searchResultsLocalFolder];
        [_searchResultsFolderNames addObject:searchResultsLocalFolder];
        
        _searchRemoteFolderName = remoteFolderName;
        _searchResultsLocalFolderName = searchResultsLocalFolder;
    } else {
        NSInteger index = [self getSearchIndex:_searchResultsLocalFolderName];
        NSAssert(index == 0, @"no index for existing search results folder");
        
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[[appDelegate model] localFolderRegistry] removeLocalFolder:_searchResultsLocalFolderName];
        
        if([[[appDelegate model] localFolderRegistry] createLocalFolder:_searchResultsLocalFolderName remoteFolder:_searchRemoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO] == nil) {
            NSAssert(false, @"could not create local folder for search results");
        }

        Boolean preserveSelection = NO;
        [[[appDelegate appController] messageListViewController] reloadMessageList:preserveSelection];
    }
    
    NSString *remoteFolderName = _searchRemoteFolderName;
    
    [self clearPreviousSearch];
    [self updateSearchMenuContent:@[]];
    
    NSUInteger searchId = _currentSearchId;
    
    //
    // Load search results to the suggestions menu.
    //
    
    if(_mainSearchPart != nil) {
        SearchExpressionKind kinds[] = {
            SearchExpressionKind_To,
            SearchExpressionKind_From,
            SearchExpressionKind_Cc,
            SearchExpressionKind_Subject
        };
        
        for(int i = 0; i < sizeof(kinds)/sizeof(kinds[0]); i++) {
            SearchExpressionKind kind = kinds[i];
            
            MCOIMAPSearchExpression *searchExpression = [self buildMCOSearchExpression:_searchTokens mainSearchPart:_mainSearchPart searchKind:kind];
            MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:remoteFolderName expression:searchExpression];
            
            op.urgent = YES;
            
            [op start:^(NSError *error, MCOIndexSet *uids) {
                if(searchId != _currentSearchId) {
                    SM_LOG_INFO(@"stale SERVER suggestions search dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
                    return;
                }

                SearchOpInfo *opInfo = _suggestionSearchOps[i];
                
                if(i < _suggestionSearchOps.count && _suggestionSearchOps[i] == opInfo) {
                    SM_LOG_DEBUG(@"search kind %s: %u messages found in remote folder %@", mcoOpKinds[opInfo.kind], uids.count, remoteFolderName);
                    
                    if(uids.count > 0) {
                        [self updateSuggestionSearchResults:uids kind:opInfo.kind];
                        
                        MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:remoteFolderName requestKind:messageHeadersRequestKind uids:uids];
                        
                        op.urgent = YES;
                        
                        [op start:^(NSError *error, NSArray *imapMessages, MCOIndexSet *vanishedMessages) {
                            if(searchId != _currentSearchId) {
                                SM_LOG_INFO(@"stale SERVER suggestions search fetching dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
                                return;
                            }
                            
                            if(i < _suggestionSearchOps.count && _suggestionSearchOps[i] == opInfo) {
                                [self updateSearchMenuContent:imapMessages];
                                [self checkSuggestionSearchCompletion];
                            }
                            else {
                                SM_LOG_INFO(@"previous search aborted");
                            }
                        }];
                        
                        opInfo.op = op;
                    }
                    else {
                        [self checkSuggestionSearchCompletion];
                    }
                }
                else {
                    SM_LOG_INFO(@"previous search aborted");
                }
            }];
            
            [_suggestionSearchOps addObject:[[SearchOpInfo alloc] initWithOp:op kind:kind]];
        }
    }
    
    _completedSuggestionSearchOps = 0;
    
    //
    // Prepare the search folder.
    //
    
    [self loadSearchResults:[MCOIndexSet indexSet] remoteFolderToSearch:remoteFolderName];

    //
    // Load server contents search results to the search local folder.
    //
    
    if(_mainSearchOp != nil) {
        [_mainSearchOp.op cancel];
        _mainSearchOp = nil;
    }

    MCOIMAPSearchExpression *searchExpression = [self buildMCOSearchExpression:_searchTokens mainSearchPart:_mainSearchPart searchKind:SearchExpressionKind_Any];
    MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:remoteFolderName expression:searchExpression];
    op.urgent = YES;
  
    [op start:^(NSError *error, MCOIndexSet *uids) {
        if(searchId != _currentSearchId) {
            SM_LOG_INFO(@"stale SERVER content search dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
            return;
        }
        
        if(_mainSearchOp.op == op) {
            SM_LOG_INFO(@"Remote content search results: %u messages in remote folder %@", uids.count, remoteFolderName);

            [self loadSearchResults:uids remoteFolderToSearch:remoteFolderName];
            
            _mainSearchOp = nil;
        }
        else {
            SM_LOG_INFO(@"previous content search aborted");
        }
    }];
 
    _mainSearchOp = [[SearchOpInfo alloc] initWithOp:op kind:SearchExpressionKind_Content];

    //
    // Trigger parallel DB search.
    //

    if(_mainSearchPart != nil) {
        [_dbOps addObject:[[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:_mainSearchPart subject:nil content:nil block:^(NSArray<SMTextMessage*> *textMessages) {
            if(searchId != _currentSearchId) {
                SM_LOG_INFO(@"stale DB contact search dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
                return;
            }
            
            for(SMTextMessage *m in textMessages) {
                if(m.from != nil) {
                    [_suggestionResultsContacts addObject:m.from];
                }
                
                if(m.toList != nil) {
                    [_suggestionResultsContacts addObjectsFromArray:m.toList];
                }
                
                if(m.ccList != nil) {
                    [_suggestionResultsContacts addObjectsFromArray:m.ccList];
                }
            }
            
            SM_LOG_DEBUG(@"Total %lu messages with matching contacts found", textMessages.count);
            
            [self updateSearchMenuContent:@[]];
        }]];
        
        [_dbOps addObject:[[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:nil subject:_mainSearchPart content:nil block:^(NSArray<SMTextMessage*> *textMessages) {
            if(searchId != _currentSearchId) {
                SM_LOG_INFO(@"stale DB subject search dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
                return;
            }
            
            for(SMTextMessage *m in textMessages) {
                if(m.subject != nil) {
                    [_suggestionResultsSubjects addObject:m.subject];
                }
            }
            
            SM_LOG_DEBUG(@"Total %lu messages with matching subject found", textMessages.count);
            
            [self updateSearchMenuContent:@[]];
        }]];
    }
    
    [_dbOps addObject:[[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:nil subject:nil content:_mainSearchPart block:^(NSArray<SMTextMessage*> *textMessages) {
        if(searchId != _currentSearchId) {
            SM_LOG_INFO(@"stale DB content search dropped (stale search id %lu, current search id %lu)", searchId, _currentSearchId);
            return;
        }
        
        MCOIndexSet *uids = [MCOIndexSet indexSet];
        
        for(SMTextMessage *m in textMessages) {
            [uids addIndex:m.uid];
        }

        SM_LOG_DEBUG(@"DB content search results: %u messages in remote folder %@", uids.count, remoteFolderName);
        
        [self loadSearchResults:uids remoteFolderToSearch:remoteFolderName];
    }]];

    //
    // Finish. Report if the caller should maintain the menu open or it should be closed.
    //
    
    if(_mainSearchPart != nil) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}

- (void)loadSearchResults:(MCOIndexSet*)uids remoteFolderToSearch:(NSString*)remoteFolderName {
    BOOL updateResults;
    
    if(_searchMessagesUIDs == nil) {
        _searchMessagesUIDs = uids;
        
        updateResults = NO;
    }
    else {
        [_searchMessagesUIDs addIndexSet:uids];
        
        updateResults = YES;
    }
    
    SMSearchDescriptor *searchDescriptor = [_searchResults objectForKey:_searchResultsLocalFolderName];
    NSAssert(searchDescriptor != nil, @"searchDescriptor == nil");

    searchDescriptor.messagesLoadingStarted = YES;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] messageListController] loadSearchResults:uids remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:_searchResultsLocalFolderName updateResults:updateResults];
}

- (MCOIMAPSearchExpression*)mapSearchPartToMCOExpression:(NSString*)string kind:(SearchExpressionKind)kind {
    switch(kind) {
        case SearchExpressionKind_From:
            // TODO: add search by full name
            return [MCOIMAPSearchExpression searchFrom:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SearchExpressionKind_To:
            return [MCOIMAPSearchExpression searchTo:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SearchExpressionKind_Cc:
            return [MCOIMAPSearchExpression searchCc:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SearchExpressionKind_Subject:
            return [MCOIMAPSearchExpression searchSubject:string];
        case SearchExpressionKind_Content:
            return [MCOIMAPSearchExpression searchContent:string];
        case SearchExpressionKind_Any:
            return [MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SearchExpressionKind_From]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SearchExpressionKind_To]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SearchExpressionKind_Cc]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SearchExpressionKind_Subject]
                other:[self mapSearchPartToMCOExpression:string kind:SearchExpressionKind_Content]]]]];
        default:
            NSAssert(nil, @"Search kind %lu not supported", kind);
            return nil;
    }
}

- (NSString*)mapSearchPartToStringExpression:(NSString*)string kind:(SearchExpressionKind)kind {
    switch(kind) {
        case SearchExpressionKind_From:
            return [NSString stringWithFormat:@"from:(%@)", string];
        case SearchExpressionKind_To:
            return [NSString stringWithFormat:@"to:(%@)", string];
        case SearchExpressionKind_Cc:
            return [NSString stringWithFormat:@"cc:(%@)", string];
        case SearchExpressionKind_Subject:
            return [NSString stringWithFormat:@"subject:(%@)", string];
        case SearchExpressionKind_Content:
            return [NSString stringWithFormat:@"contains:(%@)", string];
        default:
            NSAssert(nil, @"Search kind %lu not supported", kind);
            return nil;
    }
}

- (MCOIMAPSearchExpression*)buildMCOSearchExpression:(NSArray<SMSearchToken*>*)tokens mainSearchPart:(NSString*)mainSearchPart searchKind:(SearchExpressionKind)searchKind {
    MCOIMAPSearchExpression *expression = nil;
    
    for(NSUInteger i = 0; i < tokens.count; i++) {
        MCOIMAPSearchExpression *subExpression = [self mapSearchPartToMCOExpression:tokens[i].string kind:tokens[i].kind];
        
        if(expression == nil) {
            expression = subExpression;
        }
        else {
            expression = [MCOIMAPSearchExpression searchAnd:expression other:subExpression];
        }
    }
    
    if(mainSearchPart != nil) {
        MCOIMAPSearchExpression *subExpression = [self mapSearchPartToMCOExpression:mainSearchPart kind:searchKind];
        
        if(expression == nil) {
            expression = subExpression;
        }
        else {
            expression = [MCOIMAPSearchExpression searchAnd:expression other:subExpression];
        }
    }
    
    return expression;
}

- (void)checkSuggestionSearchCompletion {
    NSAssert(_completedSuggestionSearchOps < _suggestionSearchOps.count, @"_completedSuggestionSearchOps %lu, _suggestionSearchOps.count %lu", _completedSuggestionSearchOps, _suggestionSearchOps.count);
    
    if(++_completedSuggestionSearchOps == _suggestionSearchOps.count) {
        [self finishSuggestionSearch];
    }
}

- (void)updateSuggestionSearchResults:(MCOIndexSet*)uids kind:(SearchExpressionKind)kind {
    switch(kind) {
        case SearchExpressionKind_From:
        case SearchExpressionKind_To:
        case SearchExpressionKind_Cc:
            [_contactSearchResults addIndexSet:uids];
            break;
            
        case SearchExpressionKind_Subject:
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
#if 0
    //
    // This logic is disabled.
    //
    SM_LOG_DEBUG(@"request for index %ld", index);
    
    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    NSAssert(searchDescriptor != nil, @"search descriptor not found");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolder *localFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:searchDescriptor.localFolder];
    
    [localFolder stopMessagesLoading];
    
    Boolean preserveSelection = NO;
    [[[appDelegate appController] messageListViewController] reloadMessageList:preserveSelection];
    
    [self startNewSearch:searchDescriptor.searchPattern exitingLocalFolder:localFolder.localName];
#endif
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
    [localFolder stopMessagesLoading];
    
    searchDescriptor.searchStopped = true;
    
    // TODO: stop message bodies loading?
}

- (void)stopLatestSearch {
    if(_searchResultsFolderNames.count > 0) {
        [self stopSearch:_searchResultsFolderNames.count - 1];
    }
}

- (Boolean)searchStopped:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);
    
    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    // stop message list loading, if anys
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    
    return searchDescriptor.searchStopped;
}

- (void)addContentsSection:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    NSAssert(_searchTokens.count > 0 || _mainSearchPart != nil, @"no search tokens");
    
    NSString *section = @"Contents";
    
    [[[appDelegate appController] searchMenuViewController] addSection:section];
    [[[appDelegate appController] searchMenuViewController] addItem:(_mainSearchPart != nil? _mainSearchPart : @"??? TODO") section:section target:self action:@selector(searchForContentsAction:)];
}

- (void)addContactsSection:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    for(MCOIMAPMessage *imapMessage in imapMessages) {
        if([_contactSearchResults containsIndex:imapMessage.uid]) {
            NSMutableArray *addresses = [NSMutableArray arrayWithArray:imapMessage.header.to];
            [addresses addObjectsFromArray:imapMessage.header.cc];
            [addresses addObject:imapMessage.header.from];
            
            for(MCOAddress *address in addresses) {
                NSString *nonEncodedRFC822String = address.nonEncodedRFC822String;
                
                if([[nonEncodedRFC822String lowercaseString] containsString:[_mainSearchPart lowercaseString]]) {
                    NSString *displayContactAddress = [SMAddress displayAddress:nonEncodedRFC822String];
                    
                    SM_LOG_DEBUG(@"%@ -> %@", nonEncodedRFC822String, displayContactAddress);
                    
                    [_suggestionResultsContacts addObject:displayContactAddress];
                }
            }
        }
    }
    
    if(_mainSearchPart != nil || _suggestionResultsContacts.count > 0) {
        NSArray *sortedContacts = [_suggestionResultsContacts sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
            return [str1 compare:str2];
        }];
        
        NSString *section = @"Contacts";
        [[[appDelegate appController] searchMenuViewController] addSection:section];
        
        if(_mainSearchPart != nil) {
            [[[appDelegate appController] searchMenuViewController] addItem:_mainSearchPart section:section target:self action:@selector(searchForContactAction:)];
        }
        
        for(NSString *contact in sortedContacts) {
            [[[appDelegate appController] searchMenuViewController] addItem:contact section:section target:self action:@selector(searchForContactAction:)];
        }
    }
}

- (void)addSubjectsSection:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    for(MCOIMAPMessage *imapMessage in imapMessages) {
        if([_subjectSearchResults containsIndex:imapMessage.uid]) {
            NSString *subject = imapMessage.header.subject;
            
            if(subject != nil) {
                [_suggestionResultsSubjects addObject:subject];
            }
        }
    }
    
    if(_mainSearchPart != nil || _suggestionResultsSubjects.count > 0) {
        NSArray *sortedSubjects = [_suggestionResultsSubjects sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
            return [str1 compare:str2];
        }];
        
        NSString *section = @"Subjects";
        [[[appDelegate appController] searchMenuViewController] addSection:section];
        
        if(_mainSearchPart != nil) {
            [[[appDelegate appController] searchMenuViewController] addItem:_mainSearchPart section:section target:self action:@selector(searchForSubjectAction:)];
        }
        
        for(NSString *subject in sortedSubjects) {
            [[[appDelegate appController] searchMenuViewController] addItem:subject section:section target:self action:@selector(searchForSubjectAction:)];
        }
    }
}

- (void)updateSearchMenuContent:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] searchMenuViewController] clearAllItems];
    
    // TODO: do it asynchronously
    [self addContentsSection:imapMessages];
    [self addContactsSection:imapMessages];
    [self addSubjectsSection:imapMessages];
    
    [[[appDelegate appController] searchMenuViewController] reloadItems];
    [[appDelegate appController] adjustSearchSuggestionsMenuFrame];
}

- (void)finishSuggestionSearch {
    if(_subjectSearchResults.count == 0 && _contactSearchResults.count == 0) {
        [_suggestionResultsSubjects removeAllObjects];
        [_suggestionResultsContacts removeAllObjects];
        
        [self updateSearchMenuContent:@[]];
    }
}

- (NSString*)buildSearchString:(NSArray<SMSearchToken*>*)tokens {
    NSString *string = @"";
    
    for(NSUInteger i = 0; i < tokens.count; i++) {
        SMSearchToken *token = tokens[i];
        string = [string stringByAppendingString:[self mapSearchPartToStringExpression:token.string kind:token.kind]];
        
        if(i + 1 < tokens.count) {
            string = [string stringByAppendingString:@" "];
        }
    }
    
    return string;
}

- (void)submitNewSearchRequest:(SearchExpressionKind)kind {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSString *searchItem = [[[appDelegate appController] searchMenuViewController] selectedItem];
    
    if(searchItem == nil || searchItem.length == 0) {
        SM_LOG_ERROR(@"Empty search menu item (request kind %lu)", kind);
        return;
    }
    
    [[[appDelegate appController] searchFieldViewController] deleteAllTokensAndText];

    [_searchTokens addObject:[[SMSearchToken alloc] initWithKind:kind string:searchItem]];

    for(SMSearchToken *token in _searchTokens) {
        NSString *tokenName = [self tokenKindToName:token.kind];

        [[[appDelegate appController] searchFieldViewController] addToken:tokenName contentsText:token.string representedObject:token target:self action:@selector(tokenSearchMenuAction:) editedAction:@selector(editedTokenAction:) deletedAction:@selector(deletedTokenAction:)];
    }
    
    [[appDelegate appController] startNewSearch:YES];
}

- (NSString*)tokenKindToName:(SearchExpressionKind)kind {
    NSString *tokenName = nil;
    
    switch(kind) {
        case SearchExpressionKind_From:
            tokenName = @"From";
            break;
        case SearchExpressionKind_To:
            tokenName = @"To";
            break;
        case SearchExpressionKind_Cc:
            tokenName = @"Cc";
            break;
        case SearchExpressionKind_Subject:
            tokenName = @"Subject";
            break;
        case SearchExpressionKind_Content:
            tokenName = @"Contains";
            break;
        default:
            NSAssert(nil, @"Search kind %lu not supported", kind);
    }
    
    return tokenName;
}

#pragma mark Actions

- (void)tokenSearchMenuAction:(id)sender {
    NSAssert([sender isKindOfClass:[NSView class]], @"unexpected sender (it should be SMTokenView)");
    SMTokenView *tokenView = (SMTokenView*)sender;
    
    _tokenViewWithMenu = tokenView;

    NSAssert([tokenView.representedObject isKindOfClass:[SMSearchToken class]], @"unexpected tokenView.representedObject (it should be SMSearch)");
    SMSearchToken *token = (SMSearchToken *)tokenView.representedObject;
    
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    
    SearchExpressionKind availableKinds[] = {
        SearchExpressionKind_To,
        SearchExpressionKind_From,
        SearchExpressionKind_Cc,
        SearchExpressionKind_Subject,
        SearchExpressionKind_Content
    };
    
    for(int i = 0; i < sizeof(availableKinds)/sizeof(availableKinds[0]); i++) {
        if(token.kind != availableKinds[i]) {
            NSString *tokenName = [self tokenKindToName:availableKinds[i]];

            switch(availableKinds[i]) {
                case SearchExpressionKind_To:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToTo:) keyEquivalent:@""] setTarget:self];
                    break;
                case SearchExpressionKind_From:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToFrom:) keyEquivalent:@""] setTarget:self];
                    break;
                case SearchExpressionKind_Cc:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToCc:) keyEquivalent:@""] setTarget:self];
                    break;
                case SearchExpressionKind_Subject:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToSubject:) keyEquivalent:@""] setTarget:self];
                    break;
                case SearchExpressionKind_Content:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToContent:) keyEquivalent:@""] setTarget:self];
                    break;
                default:
                    SM_FATAL(@"unexpected kind %lu", availableKinds[i]);
            }
        }
    }

    [theMenu addItem:[NSMenuItem separatorItem]];
    [[theMenu addItemWithTitle:@"Edit" action:@selector(editTokenInSearchField:) keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:@"Delete" action:@selector(deleteTokenFromSearchField:) keyEquivalent:@""] setTarget:self];
    
    [theMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, -6) inView:tokenView];
}

- (void)changeTokenKindToTo:(id)sender {
    [self changeTokenKind:SearchExpressionKind_To];
}

- (void)changeTokenKindToFrom:(id)sender {
    [self changeTokenKind:SearchExpressionKind_From];
}

- (void)changeTokenKindToCc:(id)sender {
    [self changeTokenKind:SearchExpressionKind_Cc];
}

- (void)changeTokenKindToSubject:(id)sender {
    [self changeTokenKind:SearchExpressionKind_Subject];
}

- (void)changeTokenKindToContent:(id)sender {
    [self changeTokenKind:SearchExpressionKind_Content];
}
    
- (void)changeTokenKind:(SearchExpressionKind)newKind {
    SMSearchToken *oldToken = (SMSearchToken *)_tokenViewWithMenu.representedObject;
    SMSearchToken *newToken = [[SMSearchToken alloc] initWithKind:newKind string:oldToken.string];
    NSString *newTokenName = [self tokenKindToName:newToken.kind];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] searchFieldViewController] changeToken:_tokenViewWithMenu tokenName:newTokenName contentsText:_tokenViewWithMenu.contentsText representedObject:newToken target:_tokenViewWithMenu.target action:_tokenViewWithMenu.action editedAction:_tokenViewWithMenu.editedAction deletedAction:_tokenViewWithMenu.deletedAction];
    
    [[appDelegate appController] startNewSearch:NO];
}

- (void)editTokenInSearchField:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] searchFieldViewController] editToken:_tokenViewWithMenu];

    // Note: no other actions is to trigger here. It'll be triggered by the token itself.
}

- (void)deleteTokenFromSearchField:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] searchFieldViewController] deleteToken:_tokenViewWithMenu];
    
    // Note: no other actions is to trigger here. It'll be triggered by the token itself.
}

- (void)editedTokenAction:(id)sender {
    SMTokenView *tokenView = (SMTokenView *)sender;
    SMSearchToken *token = (SMSearchToken *)tokenView.representedObject;

    // Propagate the token string the user entered to the search.
    token.string = tokenView.contentsText;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] startNewSearch:NO];
}

- (void)deletedTokenAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] startNewSearch:NO];
}

- (void)tokenSearchEditedAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] startNewSearch:NO];
}

- (void)searchForContentsAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeSearchSuggestionsMenu];
}

- (void)searchForContactAction:(id)sender {
    [self submitNewSearchRequest:SearchExpressionKind_From];
}

- (void)searchForSubjectAction:(id)sender {
    [self submitNewSearchRequest:SearchExpressionKind_Subject];
}

@end
