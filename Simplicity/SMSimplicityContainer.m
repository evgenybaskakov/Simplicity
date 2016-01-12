//
//  SMModel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMPreferencesController.h"
#import "SMSimplicityContainer.h"
#import "SMDatabase.h"
#import "SMMailbox.h"
#import "SMLocalFolderRegistry.h"
#import "SMAttachmentStorage.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxController.h"
#import "SMMessageComparators.h"
#import "SMSuggestionProvider.h"
#import "SMAddressBookController.h"

@implementation SMSimplicityContainer {
    SMPreferencesController __weak *_preferencesController;
    MCOIMAPCapabilityOperation *_capabilitiesOp;
}

@synthesize imapServerCapabilities = _imapServerCapabilities;

- (id)initWithPreferencesController:(SMPreferencesController*)preferencesController {
    self = [ super init ];
    
    if(self) {
        _preferencesController = preferencesController;
        _mailbox = [ SMMailbox new ];
        _localFolderRegistry = [ SMLocalFolderRegistry new ];
        _attachmentStorage = [ SMAttachmentStorage new ];
        _messageListController = [[ SMMessageListController alloc ] initWithModel:self ];
        _searchResultsListController = [[SMSearchResultsListController alloc] init];
        _mailboxController = [[ SMMailboxController alloc ] initWithModel:self ];
        _messageComparators = [SMMessageComparators new];
        _addressBookController = [SMAddressBookController new];
    }
    
    SM_LOG_DEBUG(@"model initialized");
          
    return self;
}

- (MCOIndexSet*)imapServerCapabilities {
    MCOIndexSet *capabilities = _imapServerCapabilities;

    SM_LOG_DEBUG(@"IMAP server capabilities: %@", capabilities);
    
    return capabilities;
}

- (void)initAccountSession:(NSUInteger)accountIdx {
    // Init the database.
    NSString *databaseFilePath = [_preferencesController databaseFilePath:accountIdx];
    const NSUInteger localStorageSize = [_preferencesController localStorageSizeMb];
    
    _database = [[SMDatabase alloc] initWithFilePath:databaseFilePath localStorageSizeMb:localStorageSize];
    
    // Init the IMAP server.
    _imapSession = [[MCOIMAPSession alloc] init];
    
    [_imapSession setPort:[_preferencesController imapPort:accountIdx]];
    [_imapSession setHostname:[_preferencesController imapServer:accountIdx]];
    [_imapSession setCheckCertificateEnabled:[_preferencesController imapNeedCheckCertificate:accountIdx]];

    MCOAuthType imapAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController imapAuthType:accountIdx]];
    if(imapAuthType == MCOAuthTypeXOAuth2 || imapAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_imapSession setOAuth2Token:@""];
    }

    [_imapSession setAuthType:imapAuthType];
    [_imapSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController imapConnectionType:accountIdx]]];
    [_imapSession setUsername:[_preferencesController imapUserName:accountIdx]];
    [_imapSession setPassword:[_preferencesController imapPassword:accountIdx]];
    
    // Init the SMTP server.
    _smtpSession = [[MCOSMTPSession alloc] init];
    
    [_smtpSession setHostname:[_preferencesController smtpServer:accountIdx]];
    [_smtpSession setPort:[_preferencesController smtpPort:accountIdx]];
    [_smtpSession setCheckCertificateEnabled:[_preferencesController smtpNeedCheckCertificate:accountIdx]];
    
    MCOAuthType smtpAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController smtpAuthType:accountIdx]];
    if(smtpAuthType == MCOAuthTypeXOAuth2 || smtpAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_smtpSession setOAuth2Token:@""];
    }

    [_smtpSession setAuthType:smtpAuthType];
    [_smtpSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController smtpConnectionType:accountIdx]]];
    [_smtpSession setUsername:[_preferencesController smtpUserName:accountIdx]];
    [_smtpSession setPassword:[_preferencesController smtpPassword:accountIdx]];
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
