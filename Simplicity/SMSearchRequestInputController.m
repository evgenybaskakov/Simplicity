//
//  SMSearchRequestInputController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMStringUtils.h"
#import "SMMessageListViewController.h"
#import "SMSectionMenuViewController.h"
#import "SMSearchToken.h"
#import "SMAbstractSearchController.h"
#import "SMTokenFieldViewController.h"
#import "SMTokenView.h"
#import "SMSearchRequestInputController.h"

@implementation SMSearchRequestInputController {
    NSMutableArray<SMSearchToken*> *_searchTokens;
    NSString *_searchPattern;
    SMTokenView *_tokenViewWithMenu;
    
}

- (NSString*)mapSearchPartToStringExpression:(NSString*)string kind:(SMSearchExpressionKind)kind {
    switch(kind) {
        case SMSearchExpressionKind_From:
            return [NSString stringWithFormat:@"from:(%@)", string];
        case SMSearchExpressionKind_To:
            return [NSString stringWithFormat:@"to:(%@)", string];
        case SMSearchExpressionKind_Cc:
            return [NSString stringWithFormat:@"cc:(%@)", string];
        case SMSearchExpressionKind_Subject:
            return [NSString stringWithFormat:@"subject:(%@)", string];
        case SMSearchExpressionKind_Content:
            return [NSString stringWithFormat:@"contains:(%@)", string];
        default:
            NSAssert(nil, @"Search kind %lu not supported", kind);
            return nil;
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

- (void)clearSuggestionsForAccount:(SMUserAccount*)account {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [[appDelegate.appController searchMenuViewController] clearItemsWithObject:account];
}

- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern {
    searchPattern = [SMStringUtils trimString:searchPattern];
    SM_LOG_INFO(@"searching for string '%@'", searchPattern);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    _searchTokens = [[[appDelegate.appController searchFieldViewController] representedTokenObjects] mutableCopy];
    
    if(searchPattern.length != 0) {
        _searchPattern = searchPattern;
    }
    else {
        _searchPattern = nil;
    }

    // Redirect the search request to the current account search controller.
    // Some time after, the controller will likely report back to us search suggestions, etc.
    [[appDelegate.currentAccount searchController] startNewSearchWithPattern:searchPattern searchTokens:_searchTokens];
    
    // Finish. Report if the caller should maintain the menu open or it should be closed.
    if(searchPattern != nil && searchPattern.length != 0) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}

- (void)submitNewSearchRequest:(SMSearchExpressionKind)kind {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    id searchItemAccount; // TODO: remove
    NSString *searchItem = [[[appDelegate appController] searchMenuViewController] getSelectedItemWithObject:&searchItemAccount];
    
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

- (void)addContentsSectionToSuggestionsMenu:(NSString*)topLevelRequest account:(SMUserAccount*)account {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    NSString *section = @"Contents";
    
    [[[appDelegate appController] searchMenuViewController] addSection:section];
    [[[appDelegate appController] searchMenuViewController] addTopLevelItem:topLevelRequest object:account section:section target:self action:@selector(searchForContentsAction:)];
    
    [self reloadSuggestionsMenu];
}

- (void)addContactsSectionToSuggestionsMenu:(NSString*)topLevelItem contacts:(NSArray*)contacts account:(SMUserAccount *)account {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    NSString *section = @"Contacts";
    [[[appDelegate appController] searchMenuViewController] addSection:section];
    
    if(topLevelItem != nil) {
        [[[appDelegate appController] searchMenuViewController] addTopLevelItem:topLevelItem object:account section:section target:self action:@selector(searchForContactAction:)];
    }
    
    for(NSString *contact in contacts) {
        [[[appDelegate appController] searchMenuViewController] addItem:contact object:account section:section target:self action:@selector(searchForContactAction:)];
    }
    
    [self reloadSuggestionsMenu];
}

- (void)addSubjectsSectionToSuggestionsMenu:(NSString*)topLevelItem subjects:(NSArray*)subjects account:(SMUserAccount*)account {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    NSString *section = @"Subjects";
    [[[appDelegate appController] searchMenuViewController] addSection:section];
    
    if(_searchPattern != nil) {
        [[[appDelegate appController] searchMenuViewController] addTopLevelItem:topLevelItem object:account section:section target:self action:@selector(searchForSubjectAction:)];
    }
    
    for(NSString *subject in subjects) {
        [[[appDelegate appController] searchMenuViewController] addItem:subject object:account section:section target:self action:@selector(searchForSubjectAction:)];
    }
    
    [self reloadSuggestionsMenu];
}

- (void)reloadSuggestionsMenu {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    [[appDelegate.appController searchMenuViewController] reloadItems];
    [appDelegate.appController adjustSearchSuggestionsMenuFrame];
}

- (NSString*)tokenKindToName:(SMSearchExpressionKind)kind {
    NSString *tokenName = nil;
    
    switch(kind) {
        case SMSearchExpressionKind_From:
            tokenName = @"From";
            break;
        case SMSearchExpressionKind_To:
            tokenName = @"To";
            break;
        case SMSearchExpressionKind_Cc:
            tokenName = @"Cc";
            break;
        case SMSearchExpressionKind_Subject:
            tokenName = @"Subject";
            break;
        case SMSearchExpressionKind_Content:
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
    
    SMSearchExpressionKind availableKinds[] = {
        SMSearchExpressionKind_To,
        SMSearchExpressionKind_From,
        SMSearchExpressionKind_Cc,
        SMSearchExpressionKind_Subject,
        SMSearchExpressionKind_Content
    };
    
    for(int i = 0; i < sizeof(availableKinds)/sizeof(availableKinds[0]); i++) {
        if(token.kind != availableKinds[i]) {
            NSString *tokenName = [self tokenKindToName:availableKinds[i]];
            
            switch(availableKinds[i]) {
                case SMSearchExpressionKind_To:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToTo:) keyEquivalent:@""] setTarget:self];
                    break;
                case SMSearchExpressionKind_From:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToFrom:) keyEquivalent:@""] setTarget:self];
                    break;
                case SMSearchExpressionKind_Cc:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToCc:) keyEquivalent:@""] setTarget:self];
                    break;
                case SMSearchExpressionKind_Subject:
                    [[theMenu addItemWithTitle:tokenName action:@selector(changeTokenKindToSubject:) keyEquivalent:@""] setTarget:self];
                    break;
                case SMSearchExpressionKind_Content:
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
    [self changeTokenKind:SMSearchExpressionKind_To];
}

- (void)changeTokenKindToFrom:(id)sender {
    [self changeTokenKind:SMSearchExpressionKind_From];
}

- (void)changeTokenKindToCc:(id)sender {
    [self changeTokenKind:SMSearchExpressionKind_Cc];
}

- (void)changeTokenKindToSubject:(id)sender {
    [self changeTokenKind:SMSearchExpressionKind_Subject];
}

- (void)changeTokenKindToContent:(id)sender {
    [self changeTokenKind:SMSearchExpressionKind_Content];
}

- (void)changeTokenKind:(SMSearchExpressionKind)newKind {
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
    [self submitNewSearchRequest:SMSearchExpressionKind_From];
}

- (void)searchForSubjectAction:(id)sender {
    [self submitNewSearchRequest:SMSearchExpressionKind_Subject];
}

@end
