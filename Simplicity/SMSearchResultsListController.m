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
    NSArray<SMSearchToken*> *_searchTokens;
    NSString *_mainSearchPart;
    NSMutableDictionary *_searchResults;
    NSMutableArray *_searchResultsFolderNames;
    NSMutableArray<SearchOpInfo*> *_suggestionSearchOps;
    NSUInteger _completedSuggestionSearchOps;
    SearchOpInfo *_contentSearchOp;
    NSMutableOrderedSet *_suggestionResultsSubjects;
    NSMutableOrderedSet *_suggestionResultsContacts;
    MCOIndexSet *_searchMessagesUIDs;
}

- (id)init {
    self = [super init];
    
    if(self != nil) {
        _searchResults = [[NSMutableDictionary alloc] init];
        _searchResultsFolderNames = [[NSMutableArray alloc] init];
        _suggestionSearchOps = [NSMutableArray array];
        _suggestionResultsSubjects = [NSMutableOrderedSet orderedSet];
        _suggestionResultsContacts = [NSMutableOrderedSet orderedSet];
    }
    
    return self;
}

- (void)clearPreviousSearch {
    for(SearchOpInfo *opInfo in _suggestionSearchOps) {
        [opInfo.op cancel];
    }
    
    [_contentSearchOp.op cancel];
    
    [_suggestionSearchOps removeAllObjects];
    _contentSearchOp = nil;
    
    _subjectSearchResults = [MCOIndexSet indexSet];
    _contactSearchResults = [MCOIndexSet indexSet];
    
    _suggestionResultsSubjects = [NSMutableOrderedSet orderedSet];
    _suggestionResultsContacts = [NSMutableOrderedSet orderedSet];
    
    _searchMessagesUIDs = nil;
}

- (NSArray<SMSearchToken*>*)parseSearchString:(NSString*)searchString mainSearchPart:(NSString**)mainSearchPart {
    NSMutableArray<SMSearchToken*> *tokens = [NSMutableArray array];
    
    NSArray<NSString*> *expressions = @[
                                        @"to:",
                                        @"from:",
                                        @"cc:",
                                        @"subject:",
                                        @"contains:"
                                        ];
    
    SearchExpressionKind exprKinds[] = {
        SearchExpressionKind_To,
        SearchExpressionKind_From,
        SearchExpressionKind_Cc,
        SearchExpressionKind_Subject,
        SearchExpressionKind_Contents
    };
    
    NSUInteger i = 0, maxExprOffset = 0;
    for(NSString *expr in expressions) {
        NSRange searchRange = NSMakeRange(0, searchString.length);
        
        while(searchRange.location < searchString.length) {
            NSRange r = [searchString rangeOfString:expr options:NSCaseInsensitiveSearch range:searchRange];
            
            if(r.location == NSNotFound) {
                break;
            }
            
            if(r.location == 0 || !isalnum([searchString characterAtIndex:r.location-1])) {
                r.location += expr.length;
                
                if(r.location < searchString.length) {
                    while(r.location < searchString.length && isspace([searchString characterAtIndex:r.location])) {
                        r.location++;
                    }
                    
                    if(r.location < searchString.length) {
                        NSValue *rangeValue = nil;
                        
                        if([searchString characterAtIndex:r.location] == '(') {
                            NSRange rr = [searchString rangeOfString:@")" options:NSCaseInsensitiveSearch range:NSMakeRange(r.location, searchString.length - r.location)];
                            
                            if(rr.location != NSNotFound) {
                                if(r.location + 1 < rr.location) {
                                    rangeValue = [NSValue valueWithRange:NSMakeRange(r.location + 1, rr.location - r.location - 1)];
                                    r.location = rr.location + 1;
                                }
                            }
                            else {
                                if(r.location + 1 < searchString.length) {
                                    rangeValue = [NSValue valueWithRange:NSMakeRange(r.location + 1, searchString.length - r.location - 1)];
                                    r.location = searchString.length;
                                }
                            }
                        }
                        else {
                            NSRange rr = [searchString rangeOfString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(r.location, searchString.length - r.location)];
                            
                            if(rr.location != NSNotFound) {
                                if(r.location < rr.location) {
                                    rangeValue = [NSValue valueWithRange:NSMakeRange(r.location, rr.location - r.location)];
                                    r.location = rr.location + 1;
                                }
                            }
                            else {
                                if(r.location < searchString.length) {
                                    rangeValue = [NSValue valueWithRange:NSMakeRange(r.location, searchString.length - r.location)];
                                    r.location = searchString.length;
                                }
                            }
                        }
                        
                        if(rangeValue != nil) {
                            NSRange range = [rangeValue rangeValue];
                            maxExprOffset = MAX(maxExprOffset, r.location);
                            
                            [tokens addObject:[[SMSearchToken alloc] initWithKind:exprKinds[i] string:[searchString substringWithRange:range]]];
                        }
                        else {
                            r.location++;
                        }
                    }
                }
                
                NSAssert(searchRange.location < r.location, @"expr location %lu not increasing", r.location);
                searchRange.location = r.location;
            }
            else {
                searchRange.location++;
            }
            
            if(r.location >= searchString.length) {
                break;
            }
            
            searchRange.length = searchString.length - searchRange.location;
        }
        
        i++;
    }
    
    while(maxExprOffset < searchString.length && isspace([searchString characterAtIndex:maxExprOffset])) {
        maxExprOffset++;
    }
    
    if(maxExprOffset < searchString.length) {
        NSRange range = NSMakeRange(maxExprOffset, searchString.length - maxExprOffset);
        *mainSearchPart = [searchString substringWithRange:range];
    }
    else {
        *mainSearchPart = nil;
    }
    
    return tokens;
}

- (BOOL)startNewSearch:(NSString*)searchString exitingLocalFolder:(NSString*)existingLocalFolder {
    searchString = [SMStringUtils trimString:searchString];
    SM_LOG_DEBUG(@"searching for string '%@'", searchString);
    
    NSString *mainSearchPart;
    _searchTokens = [self parseSearchString:searchString mainSearchPart:&mainSearchPart];
    NSAssert(_searchTokens.count != 0 || mainSearchPart != nil, @"no search tokens");
    
    _mainSearchPart = mainSearchPart;
    _originalSearchString = searchString;
    
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
    [self updateSearchMenuContent:@[]];
    
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
                SearchOpInfo *opInfo = _suggestionSearchOps[i];
                
                if(i < _suggestionSearchOps.count && _suggestionSearchOps[i] == opInfo) {
                    SM_LOG_INFO(@"search kind %s: %u messages found in remote folder %@", mcoOpKinds[opInfo.kind], uids.count, remoteFolderName);
                    
                    if(uids.count > 0) {
                        [self updateSuggestionSearchResults:uids kind:opInfo.kind];
                        
                        MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:remoteFolderName requestKind:messageHeadersRequestKind uids:uids];
                        
                        op.urgent = YES;
                        
                        [op start:^(NSError *error, NSArray *imapMessages, MCOIndexSet *vanishedMessages) {
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
    // Load contents search results to the search local folder.
    //
    
    if(_contentSearchOp != nil) {
        [_contentSearchOp.op cancel];
    }
    
    MCOIMAPSearchOperation *op = [session searchOperationWithFolder:remoteFolderName kind:MCOIMAPSearchKindContent searchString:searchString];
    
    op.urgent = NO;
  
    [op start:^(NSError *error, MCOIndexSet *uids) {
        if(_contentSearchOp.op == op) {
            SM_LOG_INFO(@"Remote content search results: %u messages in remote folder %@", uids.count, remoteFolderName);

            [self loadSearchResults:uids remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:searchResultsLocalFolder];
            
            _contentSearchOp = nil;
        }
        else {
            SM_LOG_INFO(@"previous content search aborted");
        }
    }];
 
    _contentSearchOp = [[SearchOpInfo alloc] initWithOp:op kind:SearchExpressionKind_Contents];
    
    //
    // Trigger parallel DB search.
    //
    
    if(_mainSearchPart != nil && _mainSearchPart.length > 0) {
        [[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:_mainSearchPart subject:nil content:nil block:^(NSArray<SMTextMessage*> *textMessages){
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
            
            SM_LOG_INFO(@"Total %lu messages with matching contacts found", textMessages.count);
            
            [self updateSearchMenuContent:@[]];
        }];
        
        [[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:nil subject:_mainSearchPart content:nil block:^(NSArray<SMTextMessage*> *textMessages){
            for(SMTextMessage *m in textMessages) {
                if(m.subject != nil) {
                    [_suggestionResultsSubjects addObject:m.subject];
                }
            }
            
            SM_LOG_INFO(@"Total %lu messages with matching subject found", textMessages.count);
            
            [self updateSearchMenuContent:@[]];
        }];
        
        [[[appDelegate model] database] findMessages:remoteFolderName tokens:_searchTokens contact:nil subject:nil content:_mainSearchPart block:^(NSArray<SMTextMessage*> *textMessages) {
            MCOIndexSet *uids = [MCOIndexSet indexSet];
            
            for(SMTextMessage *m in textMessages) {
                [uids addIndex:m.uid];
            }

            SM_LOG_INFO(@"DB content search results: %u messages in remote folder %@", uids.count, remoteFolderName);
            
            [self loadSearchResults:uids remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:searchResultsLocalFolder];
        }];
    }
    
    //
    // Finish. Report if the caller should maintain the menu open or it should closed.
    //
    
    if(_mainSearchPart != nil) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}

- (void)loadSearchResults:(MCOIndexSet*)uids remoteFolderToSearch:(NSString*)remoteFolderName searchResultsLocalFolder:(NSString*)searchResultsLocalFolder {
    if(uids.count == 0) {
        return;
    }
    
    BOOL updateResults;
    
    if(_searchMessagesUIDs == nil) {
        _searchMessagesUIDs = uids;
        
        updateResults = NO;
    }
    else {
        [_searchMessagesUIDs addIndexSet:uids];
        
        updateResults = YES;
    }
    
    SMSearchDescriptor *searchDescriptor = [_searchResults objectForKey:searchResultsLocalFolder];
    NSAssert(searchDescriptor != nil, @"searchDescriptor == nil");

    searchDescriptor.messagesLoadingStarted = YES;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate model] messageListController] loadSearchResults:uids remoteFolderToSearch:remoteFolderName searchResultsLocalFolder:searchResultsLocalFolder updateResults:updateResults];
    
    [[[appDelegate appController] searchResultsListViewController] selectSearchResult:searchResultsLocalFolder];
    [[[appDelegate appController] searchResultsListViewController] reloadData];
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
        case SearchExpressionKind_Contents:
            return [MCOIMAPSearchExpression searchContent:string];
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
        case SearchExpressionKind_Contents:
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
    SM_LOG_DEBUG(@"request for index %ld", index);
    
    NSAssert(index >= 0 && index < _searchResultsFolderNames.count, @"index is out of bounds");
    
    SMSearchDescriptor *searchDescriptor = [self getSearchResults:index];
    NSAssert(searchDescriptor != nil, @"search descriptor not found");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMLocalFolder *localFolder = [[[appDelegate model] localFolderRegistry] getLocalFolder:searchDescriptor.localFolder];
    
    [localFolder stopMessagesLoading:YES];
    
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
    [[appDelegate appController] adjustSearchMenuFrame];
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
    
    NSString *newSearchString = @"";
    
    if(_searchTokens.count > 0) {
        newSearchString = [self buildSearchString:_searchTokens];
        newSearchString = [newSearchString stringByAppendingString:@" "];
    }
    
    newSearchString = [newSearchString stringByAppendingString:[self mapSearchPartToStringExpression:searchItem kind:kind]];
    newSearchString = [newSearchString stringByAppendingString:@" "];
    
    [[[appDelegate appController] searchField] setStringValue:newSearchString];
    [[[[appDelegate appController] searchField] currentEditor] moveToEndOfLine:nil];
    
    [[appDelegate appController] searchUsingToolbarSearchField:self];
}

#pragma mark Actions

- (void)searchForContentsAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[appDelegate appController] closeSearchMenu];
}

- (void)searchForContactAction:(id)sender {
    [self submitNewSearchRequest:SearchExpressionKind_From];
}

- (void)searchForSubjectAction:(id)sender {
    [self submitNewSearchRequest:SearchExpressionKind_Subject];
}

@end
