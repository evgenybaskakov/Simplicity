//
//  SMSimplicityContainer.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMSimplicityContainer.h"
#import "SMDatabase.h"
#import "SMMailbox.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxController.h"
#import "SMSuggestionProvider.h"

@implementation SMSimplicityContainer {
    SMPreferencesController __weak *_preferencesController;
    MCOIMAPCapabilityOperation *_capabilitiesOp;
}

@synthesize imapServerCapabilities = _imapServerCapabilities;

- (id)initWithAccount:(SMUserAccount*)account preferencesController:(SMPreferencesController*)preferencesController {
    self = [ super init ];
    
    if(self) {
        _account = account;
        _preferencesController = preferencesController; // TODO: why?
        _mailbox = [ SMMailbox new ];
        _localFolderRegistry = [[SMLocalFolderRegistry alloc] initWithUserAccount:_account];
        _messageListController = [[SMMessageListController alloc] initWithUserAccount:_account];
        _searchResultsListController = [[SMSearchResultsListController alloc] initWithUserAccount:_account];
        _mailboxController = [[SMMailboxController alloc] initWithUserAccount:_account];
    }
    
    SM_LOG_DEBUG(@"model initialized");
          
    return self;
}

- (MCOIndexSet*)imapServerCapabilities {
    MCOIndexSet *capabilities = _imapServerCapabilities;

    SM_LOG_DEBUG(@"IMAP server capabilities: %@", capabilities);
    
    return capabilities;
}

- (void)initSession {
    // Init the database.
    NSString *databaseFilePath = [_preferencesController databaseFilePath:_account.accountIdx];
    const NSUInteger localStorageSize = [_preferencesController localStorageSizeMb];
    
    _database = [[SMDatabase alloc] initWithFilePath:databaseFilePath localStorageSizeMb:localStorageSize];
    
    // Init the IMAP server.
    _imapSession = [[MCOIMAPSession alloc] init];
    
    [_imapSession setPort:[_preferencesController imapPort:_account.accountIdx]];
    [_imapSession setHostname:[_preferencesController imapServer:_account.accountIdx]];
    [_imapSession setCheckCertificateEnabled:[_preferencesController imapNeedCheckCertificate:_account.accountIdx]];

    MCOAuthType imapAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController imapAuthType:_account.accountIdx]];
    if(imapAuthType == MCOAuthTypeXOAuth2 || imapAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_imapSession setOAuth2Token:@""];
    }

    [_imapSession setAuthType:imapAuthType];
    [_imapSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController imapConnectionType:_account.accountIdx]]];
    [_imapSession setUsername:[_preferencesController imapUserName:_account.accountIdx]];
    [_imapSession setPassword:[_preferencesController imapPassword:_account.accountIdx]];
    
    // Init the SMTP server.
    _smtpSession = [[MCOSMTPSession alloc] init];
    
    [_smtpSession setHostname:[_preferencesController smtpServer:_account.accountIdx]];
    [_smtpSession setPort:[_preferencesController smtpPort:_account.accountIdx]];
    [_smtpSession setCheckCertificateEnabled:[_preferencesController smtpNeedCheckCertificate:_account.accountIdx]];
    
    MCOAuthType smtpAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController smtpAuthType:_account.accountIdx]];
    if(smtpAuthType == MCOAuthTypeXOAuth2 || smtpAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_smtpSession setOAuth2Token:@""];
    }

    [_smtpSession setAuthType:smtpAuthType];
    [_smtpSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController smtpConnectionType:_account.accountIdx]]];
    [_smtpSession setUsername:[_preferencesController smtpUserName:_account.accountIdx]];
    [_smtpSession setPassword:[_preferencesController smtpPassword:_account.accountIdx]];
}

- (void)getIMAPServerCapabilities {
    NSAssert(_capabilitiesOp == nil, @"_capabilitiesOp is not nil");
        
    _capabilitiesOp = [_imapSession capabilityOperation];
    
    void (^opBlock)(NSError*, MCOIndexSet*) = nil;
    
    opBlock = ^(NSError * error, MCOIndexSet * capabilities) {
        if(error) {
            SM_LOG_ERROR(@"error getting IMAP capabilities: %@", error);

            [_capabilitiesOp start:opBlock];
        } else {
            SM_LOG_DEBUG(@"IMAP server capabilities: %@", capabilities);
            
            SM_LOG_INFO(@"IMAP server folder concurrent access is %@, maximum %u connections allowed", _imapSession.allowsFolderConcurrentAccessEnabled? @"ENABLED" : @"DISABLED", _imapSession.maximumConnections);
            
            _imapServerCapabilities = capabilities;
            _capabilitiesOp = nil;
        }
    };

    [_capabilitiesOp start:opBlock];
}

@end
