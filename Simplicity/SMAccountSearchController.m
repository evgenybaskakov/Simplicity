//
//  SMAccountSearchController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/7/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMDatabase.h"
#import "SMStringUtils.h"
#import "SMAddress.h"
#import "SMSearchToken.h"
#import "SMSearchDescriptor.h"
#import "SMTextMessage.h"
#import "SMAccountMailbox.h"
#import "SMFolder.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMSearchExpressionKind.h"
#import "SMSearchRequestInputController.h"
#import "SMAccountSearchController.h"

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
@property (readonly) SMSearchExpressionKind kind;
@property MCOIMAPBaseOperation *op;
@end

@implementation SearchOpInfo
- (id)initWithOp:(MCOIMAPSearchOperation*)op kind:(SMSearchExpressionKind)kind {
    self = [super init];
    
    if(self) {
        _op = op;
        _kind = kind;
    }
    
    return self;
}
@end

@implementation SMAccountSearchController {
    NSUInteger _currentSearchId;
    NSMutableDictionary *_searchResults;
    NSMutableArray *_searchResultsFolderNames;
    NSMutableArray<SearchOpInfo*> *_suggestionSearchOps;
    NSUInteger _completedSuggestionSearchOps;
    SearchOpInfo *_mainSearchOp;
    NSMutableOrderedSet *_suggestionResultsSubjects;
    NSMutableOrderedSet *_suggestionResultsContacts;
    MCOIndexSet *_searchMessagesUIDs;
    NSString *_searchRemoteFolderName;
    NSString *_searchResultsLocalFolderName;
    NSMutableArray<SMDatabaseOp*> *_dbOps;
    MCOIndexSet *_subjectSearchResults;
    MCOIndexSet *_contactSearchResults;
}

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
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

- (void)startNewSearchWithPattern:(NSString*)searchPattern searchTokens:(NSArray<SMSearchToken*>*)searchTokens {
    NSAssert(searchPattern != nil || searchTokens.count != 0, @"no search tokens and pattern provided by the caller");
    
    MCOIMAPSession *session = [(SMUserAccount*)_account imapSession];
    NSAssert(session, @"session is nil");
    
    if(_searchResultsLocalFolderName == nil) {
        // TODO: introduce search results descriptor to avoid this funny folder name
        _searchResultsLocalFolderName = [NSString stringWithFormat:@"//search_results//0"];
    
        NSString *allMailFolder = [[[_account mailbox] allMailFolder] fullName]; // TODO: provide a choice
        if(allMailFolder != nil) {
            _searchRemoteFolderName = allMailFolder;

            SM_LOG_DEBUG(@"searching in all mail (%@)", _searchRemoteFolderName);
        } else {
            // TODO: will require another logic for non-gmail accounts
            _searchRemoteFolderName = [[[_account messageListController] currentLocalFolder] remoteFolderName];
            
            SM_LOG_DEBUG(@"searching in %@", _searchRemoteFolderName);
        }
    }
    
    // Remove the folder with old results.
    if([_searchResults objectForKey:_searchResultsLocalFolderName]) {
        [[_account localFolderRegistry] removeLocalFolder:_searchResultsLocalFolderName];
    }
    
    // Create a new folder which will contain new search results.
    [[_account localFolderRegistry] createLocalFolder:_searchResultsLocalFolderName remoteFolder:_searchRemoteFolderName kind:SMFolderKindSearch syncWithRemoteFolder:NO];
       
    SMSearchDescriptor *searchDescriptor = [[SMSearchDescriptor alloc] init:searchPattern localFolder:_searchResultsLocalFolderName remoteFolder:_searchRemoteFolderName];
    
    [_searchResults setObject:searchDescriptor forKey:_searchResultsLocalFolderName];
    [_searchResultsFolderNames addObject:_searchResultsLocalFolderName];
    
    [self clearPreviousSearch];
    [self updateSearchMenuContent:searchPattern imapMessages:@[]];
    
    NSUInteger searchId = _currentSearchId;
    
    //
    // Load search results to the suggestions menu.
    //
    
    if(searchPattern != nil) {
        SMSearchExpressionKind kinds[] = {
            SMSearchExpressionKind_To,
            SMSearchExpressionKind_From,
            SMSearchExpressionKind_Cc,
            SMSearchExpressionKind_Subject
        };
        
        for(int i = 0; i < sizeof(kinds)/sizeof(kinds[0]); i++) {
            SMSearchExpressionKind kind = kinds[i];
            
            MCOIMAPSearchExpression *searchExpression = [self buildMCOSearchExpression:searchTokens searchPattern:searchPattern searchKind:kind];
            MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:_searchRemoteFolderName expression:searchExpression];
            
            op.urgent = YES;
            
            SMAccountSearchController __weak *weakSelf = self;
            [op start:^(NSError *error, MCOIndexSet *uids) {
                SMAccountSearchController *_self = weakSelf;
                if(!_self) {
                    SM_LOG_WARNING(@"object is gone");
                    return;
                }
                
                NSUInteger currentSearchId = _self->_currentSearchId;
                NSMutableArray<SearchOpInfo*> *suggestionSearchOps = _self->_suggestionSearchOps;
                NSString *searchRemoteFolderName = _self->_searchRemoteFolderName;
                
                if(searchId != currentSearchId) {
                    SM_LOG_INFO(@"stale SERVER suggestions search dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
                    return;
                }

                SearchOpInfo *opInfo = suggestionSearchOps[i];
                
                if(i < suggestionSearchOps.count && suggestionSearchOps[i] == opInfo) {
                    if(error == nil || error.code == MCOErrorNone) {
                        SM_LOG_DEBUG(@"search kind %s: %u messages found in remote folder %@", mcoOpKinds[opInfo.kind], uids.count, searchRemoteFolderName);
                    }
                    else {
                        SM_LOG_ERROR(@"search kind %s: search in folder %@ failed: %@", mcoOpKinds[opInfo.kind], searchRemoteFolderName, error);
                        uids = nil;
                    }
                    
                    if(uids != nil && uids.count > 0) {
                        [_self updateSuggestionSearchResults:uids kind:opInfo.kind];
                        
                        MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:searchRemoteFolderName requestKind:messageHeadersRequestKind uids:uids];
                        
                        op.urgent = YES;
                        
                        [op start:^(NSError *error, NSArray *imapMessages, MCOIndexSet *vanishedMessages) {
                            if(searchId != currentSearchId) {
                                SM_LOG_INFO(@"stale SERVER suggestions search fetching dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
                                return;
                            }
                            
                            if(i < suggestionSearchOps.count && suggestionSearchOps[i] == opInfo) {
                                [_self updateSearchMenuContent:searchPattern imapMessages:imapMessages];
                                [_self checkSuggestionSearchCompletion:searchPattern];
                            }
                            else {
                                SM_LOG_INFO(@"previous search aborted");
                            }
                        }];
                        
                        opInfo.op = op;
                    }
                    else {
                        [_self checkSuggestionSearchCompletion:searchPattern];
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
    
    [self loadSearchResults:[MCOIndexSet indexSet] remoteFolderToSearch:_searchRemoteFolderName];

    //
    // Load server contents search results to the search local folder.
    //
    
    if(_mainSearchOp != nil) {
        [_mainSearchOp.op cancel];
        _mainSearchOp = nil;
    }

    MCOIMAPSearchExpression *searchExpression = [self buildMCOSearchExpression:searchTokens searchPattern:searchPattern searchKind:SMSearchExpressionKind_Any];
    MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:_searchRemoteFolderName expression:searchExpression];
    op.urgent = YES;

    SMAccountSearchController __weak *weakSelf = self;
    [op start:^(NSError *error, MCOIndexSet *uids) {
        SMAccountSearchController *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }

        NSUInteger currentSearchId = _self->_currentSearchId;
        NSString *searchRemoteFolderName = _self->_searchRemoteFolderName;
        SearchOpInfo *mainSearchOp = _self->_mainSearchOp;

        if(searchId != currentSearchId) {
            SM_LOG_INFO(@"stale SERVER content search dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
            return;
        }
        
        if(error == nil || error.code == MCOErrorNone) {
            if(mainSearchOp.op == op) {
                SM_LOG_INFO(@"Remote content search results: %u messages in remote folder %@", uids.count, searchRemoteFolderName);

                [_self loadSearchResults:uids remoteFolderToSearch:searchRemoteFolderName];
            }
            else {
                SM_LOG_INFO(@"previous content search aborted");
            }
        }
        else {
            SM_LOG_ERROR(@"search in folder %@ failed: %@", searchRemoteFolderName, error);
        }

        if(mainSearchOp.op == op) {
            mainSearchOp = nil;
        }
    }];
 
    _mainSearchOp = [[SearchOpInfo alloc] initWithOp:op kind:SMSearchExpressionKind_Content];

    //
    // Trigger parallel DB search.
    //

    if(searchPattern != nil) {
        [_dbOps addObject:[[_account database] findMessages:_searchRemoteFolderName tokens:searchTokens contact:searchPattern subject:nil content:nil block:^(SMDatabaseOp *op, NSArray<SMTextMessage*> *textMessages) {
            SMAccountSearchController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }

            [_self->_dbOps removeObject:op];
            
            NSUInteger currentSearchId = _self->_currentSearchId;
            NSMutableOrderedSet *suggestionResultsContacts = _self->_suggestionResultsContacts;
            
            if(searchId != currentSearchId) {
                SM_LOG_INFO(@"stale DB contact search dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
                return;
            }
            
            for(SMTextMessage *m in textMessages) {
                if(m.from != nil) {
                    [suggestionResultsContacts addObject:m.from];
                }
                
                if(m.toList != nil) {
                    [suggestionResultsContacts addObjectsFromArray:m.toList];
                }
                
                if(m.ccList != nil) {
                    [suggestionResultsContacts addObjectsFromArray:m.ccList];
                }
            }
            
            SM_LOG_DEBUG(@"Total %lu messages with matching contacts found", textMessages.count);
            
            [_self updateSearchMenuContent:searchPattern imapMessages:@[]];
        }]];
        
        [_dbOps addObject:[[_account database] findMessages:_searchRemoteFolderName tokens:searchTokens contact:nil subject:searchPattern content:nil block:^(SMDatabaseOp *op, NSArray<SMTextMessage*> *textMessages) {
            SMAccountSearchController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }

            [_self->_dbOps removeObject:op];
            
            NSUInteger currentSearchId = _self->_currentSearchId;
            NSMutableOrderedSet *suggestionResultsSubjects = _self->_suggestionResultsSubjects;
            
            if(searchId != currentSearchId) {
                SM_LOG_INFO(@"stale DB subject search dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
                return;
            }
            
            for(SMTextMessage *m in textMessages) {
                if(m.subject != nil) {
                    [suggestionResultsSubjects addObject:m.subject];
                }
            }
            
            SM_LOG_DEBUG(@"Total %lu messages with matching subject found", textMessages.count);
            
            [_self updateSearchMenuContent:searchPattern imapMessages:@[]];
        }]];
    }
    
    [_dbOps addObject:[[_account database] findMessages:_searchRemoteFolderName tokens:searchTokens contact:nil subject:nil content:searchPattern block:^(SMDatabaseOp *op, NSArray<SMTextMessage*> *textMessages) {
        SMAccountSearchController *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }

        [_self->_dbOps removeObject:op];
        
        NSUInteger currentSearchId = _self->_currentSearchId;
        NSString *searchRemoteFolderName = _self->_searchRemoteFolderName;

        if(searchId != currentSearchId) {
            SM_LOG_INFO(@"stale DB content search dropped (stale search id %lu, current search id %lu)", searchId, currentSearchId);
            return;
        }
        
        MCOIndexSet *uids = [MCOIndexSet indexSet];
        
        for(SMTextMessage *m in textMessages) {
            [uids addIndex:m.uid];
        }

        SM_LOG_DEBUG(@"DB content search results: %u messages in remote folder %@", uids.count, searchRemoteFolderName);
        
        [_self loadSearchResults:uids remoteFolderToSearch:searchRemoteFolderName];
    }]];
}

- (void)loadSearchResults:(MCOIndexSet*)uids remoteFolderToSearch:(NSString*)remoteFolderName {
    BOOL changeFolder;
    
    if(_searchMessagesUIDs == nil) {
        _searchMessagesUIDs = uids;
        
        changeFolder = YES;
    }
    else {
        [_searchMessagesUIDs addIndexSet:uids];
        
        changeFolder = NO;
    }
    
    SMSearchDescriptor *searchDescriptor = [_searchResults objectForKey:_searchResultsLocalFolderName];
    NSAssert(searchDescriptor != nil, @"searchDescriptor == nil");

    searchDescriptor.messagesLoadingStarted = YES;
    
    [[_account messageListController] loadSearchResults:uids remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:_searchResultsLocalFolderName changeFolder:changeFolder];
}

- (MCOIMAPSearchExpression*)mapSearchPartToMCOExpression:(NSString*)string kind:(SMSearchExpressionKind)kind {
    switch(kind) {
        case SMSearchExpressionKind_From:
            // TODO: add search by full name
            return [MCOIMAPSearchExpression searchFrom:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SMSearchExpressionKind_To:
            return [MCOIMAPSearchExpression searchTo:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SMSearchExpressionKind_Cc:
            return [MCOIMAPSearchExpression searchCc:[SMAddress extractEmailFromAddressString:string name:nil]];
        case SMSearchExpressionKind_Subject:
            return [MCOIMAPSearchExpression searchSubject:string];
        case SMSearchExpressionKind_Content:
            return [MCOIMAPSearchExpression searchContent:string];
        case SMSearchExpressionKind_Any:
            return [MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SMSearchExpressionKind_From]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SMSearchExpressionKind_To]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SMSearchExpressionKind_Cc]
                other:[MCOIMAPSearchExpression searchOr:[self mapSearchPartToMCOExpression:string kind:SMSearchExpressionKind_Subject]
                other:[self mapSearchPartToMCOExpression:string kind:SMSearchExpressionKind_Content]]]]];
        default:
            NSAssert(nil, @"Search kind %lu not supported", kind);
            return nil;
    }
}

- (MCOIMAPSearchExpression*)buildMCOSearchExpression:(NSArray<SMSearchToken*>*)tokens searchPattern:(NSString*)searchPattern searchKind:(SMSearchExpressionKind)searchKind {
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
    
    if(searchPattern != nil) {
        MCOIMAPSearchExpression *subExpression = [self mapSearchPartToMCOExpression:searchPattern kind:searchKind];
        
        if(expression == nil) {
            expression = subExpression;
        }
        else {
            expression = [MCOIMAPSearchExpression searchAnd:expression other:subExpression];
        }
    }
    
    return expression;
}

- (void)checkSuggestionSearchCompletion:(NSString*)searchPattern {
    NSAssert(_completedSuggestionSearchOps < _suggestionSearchOps.count, @"_completedSuggestionSearchOps %lu, _suggestionSearchOps.count %lu", _completedSuggestionSearchOps, _suggestionSearchOps.count);
    
    if(++_completedSuggestionSearchOps == _suggestionSearchOps.count) {
        [self finishSuggestionSearch:searchPattern];
    }
}

- (void)updateSuggestionSearchResults:(MCOIndexSet*)uids kind:(SMSearchExpressionKind)kind {
    switch(kind) {
        case SMSearchExpressionKind_From:
        case SMSearchExpressionKind_To:
        case SMSearchExpressionKind_Cc:
            [_contactSearchResults addIndexSet:uids];
            break;
            
        case SMSearchExpressionKind_Subject:
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

- (SMSearchDescriptor*)getSearchResults:(NSUInteger)index {
    return [_searchResults objectForKey:[_searchResultsFolderNames objectAtIndex:index]];
}

- (void)stopSearch:(NSInteger)index {
    SM_LOG_DEBUG(@"request for index %ld", index);
    
    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    // stop search op itself, if any
    [self clearPreviousSearch];
    
    // stop message list loading, if anys
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    NSAssert(searchDescriptor != nil, @"search descriptor not found");
    
    id<SMAbstractLocalFolder> localFolder = [[_account localFolderRegistry] getLocalFolderByName:searchDescriptor.localFolder];
    [localFolder stopLocalFolderSync:YES];
    
    searchDescriptor.searchStopped = true;
}

- (void)stopLatestSearch {
    if(_searchResultsFolderNames.count > 0) {
        [self stopSearch:_searchResultsFolderNames.count - 1];
    }
}

- (void)addContentsSection:(NSString*)searchPattern {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    if(searchPattern != nil) {
        NSString *sectionTitle = [NSString stringWithFormat:@"Messages contain: %@", searchPattern];
        
        [[appDelegate.appController searchRequestInputController] addContentsSectionToSuggestionsMenu:sectionTitle topLevelItemValue:searchPattern account:(SMUserAccount*)_account];
    }
}

- (void)addContactsSection:(NSString*)searchPattern imapMessages:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    for(MCOIMAPMessage *imapMessage in imapMessages) {
        if([_contactSearchResults containsIndex:imapMessage.uid]) {
            NSMutableArray *addresses = [NSMutableArray arrayWithArray:imapMessage.header.to];
            [addresses addObjectsFromArray:imapMessage.header.cc];
            [addresses addObject:imapMessage.header.from];
            
            for(MCOAddress *address in addresses) {
                NSString *nonEncodedRFC822String = address.nonEncodedRFC822String;
                
                if([[nonEncodedRFC822String lowercaseString] containsString:[searchPattern lowercaseString]]) {
                    NSString *displayContactAddress = [SMAddress displayAddress:nonEncodedRFC822String];
                    
                    SM_LOG_DEBUG(@"%@ -> %@", nonEncodedRFC822String, displayContactAddress);
                    
                    [_suggestionResultsContacts addObject:displayContactAddress];
                }
            }
        }
    }
    
    if(searchPattern != nil || _suggestionResultsContacts.count > 0) {
        NSString *sectionTitle = [NSString stringWithFormat:@"Contact contains: %@", searchPattern];
        
        [[appDelegate.appController searchRequestInputController] addContactsSectionToSuggestionsMenu:sectionTitle topLevelItemValue:searchPattern contacts:_suggestionResultsContacts.array account:(SMUserAccount*)_account];
    }
}

- (void)addSubjectsSection:(NSString*)searchPattern imapMessages:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    for(MCOIMAPMessage *imapMessage in imapMessages) {
        if([_subjectSearchResults containsIndex:imapMessage.uid]) {
            NSString *subject = imapMessage.header.subject;
            
            if(subject != nil) {
                [_suggestionResultsSubjects addObject:subject];
            }
        }
    }
    
    if(searchPattern != nil || _suggestionResultsSubjects.count > 0) {
        if(searchPattern != nil || _suggestionResultsSubjects.count > 0) {
            NSString *sectionTitle = [NSString stringWithFormat:@"Subject contains: %@", searchPattern];
            
            [[appDelegate.appController searchRequestInputController] addSubjectsSectionToSuggestionsMenu:sectionTitle topLevelItemValue:searchPattern  subjects:_suggestionResultsSubjects.array account:(SMUserAccount*)_account];
        }
    }
}

- (void)updateSearchMenuContent:(NSString*)searchPattern imapMessages:(NSArray<MCOIMAPMessage*>*)imapMessages {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    [[appDelegate.appController searchRequestInputController] clearSuggestionsForAccount:(SMUserAccount*)_account];
    
    [self addContentsSection:searchPattern];
    [self addContactsSection:searchPattern imapMessages:imapMessages];
    [self addSubjectsSection:searchPattern imapMessages:imapMessages];
}

- (void)finishSuggestionSearch:(NSString*)searchPattern {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    [[appDelegate appController] finishSearch:SMSearchOperationKind_Suggestions];
    
    if(_subjectSearchResults.count == 0 && _contactSearchResults.count == 0) {
        [_suggestionResultsSubjects removeAllObjects];
        [_suggestionResultsContacts removeAllObjects];
        
        [self updateSearchMenuContent:searchPattern imapMessages:@[]];
    }
}

@end
