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
#import "SMMessageStorage.h"
#import "SMLocalFolderRegistry.h"
#import "SMAttachmentStorage.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxController.h"
#import "SMMessageComparators.h"

@implementation SMSimplicityContainer {
    SMPreferencesController __weak *_preferencesController;
	MCOIMAPCapabilityOperation *_capabilitiesOp;
}

@synthesize imapServerCapabilities = _imapServerCapabilities;

- (id)initWithPreferencesController:(SMPreferencesController*)preferencesController {
	self = [ super init ];
	
	if(self) {
//		MCLogEnabled = 1;

        _preferencesController = preferencesController;
        
        _mailbox = [ SMMailbox new ];
		_messageStorage = [ SMMessageStorage new ];
		_localFolderRegistry = [ SMLocalFolderRegistry new ];
		_attachmentStorage = [ SMAttachmentStorage new ];
		
		_messageListController = [[ SMMessageListController alloc ] initWithModel:self ];
		_searchResultsListController = [[SMSearchResultsListController alloc] init];
		_mailboxController = [[ SMMailboxController alloc ] initWithModel:self ];
		_messageComparators = [SMMessageComparators new];
	}
	
	SM_LOG_DEBUG(@"model initialized");
		  
	return self;
}

- (MCOIndexSet*)imapServerCapabilities {
	MCOIndexSet *capabilities = _imapServerCapabilities;

	SM_LOG_DEBUG(@"IMAP server capabilities: %@", capabilities);
	
	return capabilities;
}

- (void)initAccountSession {
    // Init the database.
    _database = [[SMDatabase alloc] initWithFilePath:[_preferencesController databaseFilePath:0]];
    
    // Init the IMAP server.
    _imapSession = [[MCOIMAPSession alloc] init];
    
    [_imapSession setPort:[_preferencesController imapPort:0]];
    [_imapSession setHostname:[_preferencesController imapServer:0]];
    [_imapSession setCheckCertificateEnabled:[_preferencesController imapNeedCheckCertificate:0]];

    MCOAuthType imapAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController imapAuthType:0]];
    if(imapAuthType == MCOAuthTypeXOAuth2 || imapAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_imapSession setOAuth2Token:@""];
    }

    [_imapSession setAuthType:imapAuthType];
    [_imapSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController imapConnectionType:0]]];
    [_imapSession setUsername:[_preferencesController imapUserName:0]];
    [_imapSession setPassword:[_preferencesController imapPassword:0]];
    
    // Init the SMTP server.
    _smtpSession = [[MCOSMTPSession alloc] init];
    
    [_smtpSession setHostname:[_preferencesController smtpServer:0]];
    [_smtpSession setPort:[_preferencesController smtpPort:0]];
    [_smtpSession setCheckCertificateEnabled:[_preferencesController smtpNeedCheckCertificate:0]];
    
    MCOAuthType smtpAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController smtpAuthType:0]];
    if(smtpAuthType == MCOAuthTypeXOAuth2 || smtpAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_smtpSession setOAuth2Token:@""];
    }

    [_smtpSession setAuthType:smtpAuthType];
    [_smtpSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController smtpConnectionType:0]]];
    [_smtpSession setUsername:[_preferencesController smtpUserName:0]];
    [_smtpSession setPassword:[_preferencesController smtpPassword:0]];
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
