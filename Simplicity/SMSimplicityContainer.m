//
//  SMSimplicityContainer.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/2/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAttachmentStorage.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMSimplicityContainer.h"
#import "SMDatabase.h"
#import "SMOperationExecutor.h"
#import "SMMailbox.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMSearchResultsListController.h"
#import "SMMailboxController.h"
#import "SMOutboxController.h"
#import "SMOperationQueue.h"
#import "SMSuggestionProvider.h"
#import "SMMessage.h"

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
        _outboxController = [[SMOutboxController alloc] initWithUserAccount:_account];
        _operationExecutor = [[SMOperationExecutor alloc] initWithUserAccount:_account];
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
    _database = [[SMDatabase alloc] initWithFilePath:databaseFilePath];
    
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

- (void)initOpExecutor {
    [_mailboxController initFolders];
    
    // TODO: use the resulting dbOp
    [_database loadOpQueue:@"SMTPQueue" block:^(SMOperationQueue *smtpQueue) {
        // TODO: use the resulting dbOp
        [_database loadOpQueue:@"IMAPQueue" block:^(SMOperationQueue *imapQueue) {
            [imapQueue setOperationExecutorForPendingOps:_operationExecutor];
            [smtpQueue setOperationExecutorForPendingOps:_operationExecutor];
            
            [_operationExecutor setSmtpQueue:smtpQueue imapQueue:imapQueue];
            
            [_outboxController loadSMTPQueue:smtpQueue postSendActionTarget:_outboxController postSendActionSelector:@selector(finishMessageSending:)];
        }];
    }];
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

- (void)fetchMessageInlineAttachments:(SMMessage *)message {
    NSString *remoteFolder = message.remoteFolder;
    uint32_t uid = message.uid;
    
    NSArray *attachments = [message htmlInlineAttachments];
    if(attachments == nil) {
        SM_LOG_WARNING(@"no inline attachments for message uid %u", uid);
        return;
    }
    
    MCOIMAPMessage *imapMessage = message.imapMessage;
    if(imapMessage == nil) {
        SM_LOG_WARNING(@"no imap message for message uid %u", uid);
        return;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMAttachmentStorage *attachmentStorage = [appDelegate attachmentStorage];
    
    // TODO: fetch inline attachments on demand
    // TODO: refresh current view of the message loaded from DB without attachments
    for(MCOAttachment *attachment in attachments) {
        NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
        NSData *attachmentData = [attachment data];
        
        SM_LOG_DEBUG(@"message uid %u, attachment unique id %@, contentID %@, body %@", uid, [attachment uniqueID], attachmentContentId, attachment);
        
        NSURL *attachmentUrl = [attachmentStorage attachmentLocation:attachmentContentId uid:uid folder:remoteFolder];
        
        NSError *err;
        if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
            SM_LOG_DEBUG(@"stored attachment exists at '%@'", attachmentUrl);
            continue;
        }
        
        if(attachmentData) {
            [attachmentStorage storeAttachment:attachmentData folder:remoteFolder uid:uid contentId:attachmentContentId];
        } else {
            MCOAbstractPart *part = [imapMessage partForUniqueID:[attachment uniqueID]];
            
            NSAssert(part, @"Cannot find inline attachment part");
            NSAssert([part isKindOfClass:[MCOIMAPPart class]], @"Bad inline attachment part type");
            
            MCOIMAPPart *imapPart = (MCOIMAPPart*)part;
            NSString *partId = [imapPart partID];
            
            NSAssert([attachmentContentId isEqualToString:[imapPart contentID]], @"Attachment contentId is not equal to part contentId");
            
            SM_LOG_DEBUG(@"part %@, id %@, contentID %@", part, partId, [imapPart contentID]);
            
            // TODO: for older sessions, terminate attachment fetching
            NSAssert(_imapSession, @"bad session");
            
            MCOIMAPFetchContentOperation *op = [_imapSession fetchMessageAttachmentOperationWithFolder:remoteFolder uid:uid partID:partId encoding:[imapPart encoding] urgent:YES];
            
            // TODO: check if there is a leak if imapPart is accessed in this block!!!
            [op start:^(NSError * error, NSData * data) {
                if ([error code] == MCOErrorNone) {
                    NSAssert(data, @"no data");
                    
                    [attachmentStorage storeAttachment:data folder:remoteFolder uid:uid contentId:imapPart.contentID];
                } else {
                    SM_LOG_ERROR(@"Error downloading message body for msg uid %u, part unique id %@: %@", uid, partId, error);
                }
            }];
        }
    }
}

@end
