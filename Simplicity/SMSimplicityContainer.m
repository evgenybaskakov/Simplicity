//
//  SMModel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMMessageStorage.h"
#import "SMLocalFolderRegistry.h"
#import "SMAttachmentStorage.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxController.h"
#import "SMMessageComparators.h"
#import "SMMailLogin.h"

@implementation SMSimplicityContainer {
	MCOIMAPCapabilityOperation *_capabilitiesOp;
}

@synthesize imapServerCapabilities = _imapServerCapabilities;

- (id)init {
	self = [ super init ];
	
	if(self) {
//		MCLogEnabled = 1;

		_imapSession = [[MCOIMAPSession alloc] init];
		
		[_imapSession setPort:IMAP_SERVER_PORT];
		[_imapSession setHostname:IMAP_SERVER_HOSTNAME];
		[_imapSession setConnectionType:IMAP_SERVER_CONNECTION_TYPE];
		[_imapSession setUsername:IMAP_USERNAME];
		[_imapSession setPassword:IMAP_PASSWORD];

		_smtpSession = [[MCOSMTPSession alloc] init];
		
		[_smtpSession setAuthType:SMTP_SERVER_AUTH_TYPE];
		[_smtpSession setHostname:SMTP_SERVER_HOSTNAME];
		[_smtpSession setPort:SMTP_SERVER_PORT];
		[_smtpSession setCheckCertificateEnabled:SMTP_SERVER_CHECK_CERTIFICATE];
		[_smtpSession setConnectionType:SMTP_SERVER_CONNECTION_TYPE];
		[_smtpSession setUsername:SMTP_USERNAME];
		[_smtpSession setPassword:SMTP_PASSWORD];

		_mailbox = [ SMMailbox new ];
		_messageStorage = [ SMMessageStorage new ];
		_localFolderRegistry = [ SMLocalFolderRegistry new ];
		_attachmentStorage = [ SMAttachmentStorage new ];
		
		_messageListController = [[ SMMessageListController alloc ] initWithModel:self ];
		_searchResultsListController = [[SMSearchResultsListController alloc] init];
		_mailboxController = [[ SMMailboxController alloc ] initWithModel:self ];
		_messageComparators = [SMMessageComparators new];

		[self getIMAPServerCapabilities];
	}
	
	SM_LOG_DEBUG(@"model initialized");
		  
	return self;
}

- (MCOIndexSet*)imapServerCapabilities {
	MCOIndexSet *capabilities = _imapServerCapabilities;

	SM_LOG_DEBUG(@"IMAP server capabilities: %@", capabilities);
	
	return capabilities;
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
			SM_LOG_DEBUG(@"capabilities: %@", capabilities);
			
			_imapServerCapabilities = capabilities;
			_capabilitiesOp = nil;
		}
	};

	[_capabilitiesOp start:opBlock];
}

@end
