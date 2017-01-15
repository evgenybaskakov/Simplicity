//
//  SMUserAccount.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMStringUtils.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMAddress.h"
#import "SMAddressBookController.h"
#import "SMAccountImageSelection.h"
#import "SMAttachmentStorage.h"
#import "SMPreferencesController.h"
#import "SMDatabase.h"
#import "SMFolderColorController.h"
#import "SMOperationExecutor.h"
#import "SMAccountMailbox.h"
#import "SMMessage.h"
#import "SMMessageBodyFetchQueue.h"
#import "SMAbstractLocalFolder.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMAccountSearchController.h"
#import "SMAccountMailboxController.h"
#import "SMOutboxController.h"
#import "SMOperationQueue.h"
#import "SMOpSendMessage.h"
#import "SMSuggestionProvider.h"
#import "SMNotificationsController.h"
#import "SMFolderUpdateController.h"
#import "SMUserAccount.h"

const char *mcoConnectionTypeName(MCOConnectionLogType type) {
    switch(type) {
        case MCOConnectionLogTypeReceived: return "Received";
        case MCOConnectionLogTypeSent: return "Sent";
        case MCOConnectionLogTypeSentPrivate: return "SentPrivate";
        case MCOConnectionLogTypeErrorParse: return "ErrorParse";
        case MCOConnectionLogTypeErrorReceived: return "ErrorReceived";
        case MCOConnectionLogTypeErrorSent: return "ErrorSent";
    }
    
    return "unknown";
}

@implementation SMUserAccount {
    SMPreferencesController __weak *_preferencesController;
    MCOIndexSet *_imapServerCapabilities;
    MCOIMAPCapabilityOperation *_capabilitiesOp;
    SMFolderUpdateController *_inboxUpdateController;
}

@synthesize unified = _unified;
@synthesize folderColorController = _folderColorController;
@synthesize messageListController = _messageListController;
@synthesize searchController = _searchController;
@synthesize mailboxController = _mailboxController;
@synthesize outboxController = _outboxController;
@synthesize mailbox = _mailbox;
@synthesize database = _database;
@synthesize localFolderRegistry = _localFolderRegistry;
@synthesize foldersInitialized = _foldersInitialized;
@synthesize accountAddress = _accountAddress;
@synthesize accountImage = _accountImage;
@synthesize accountName = _accountName;

- (id)initWithPreferencesController:(SMPreferencesController*)preferencesController {
    self = [super init];
    
    if(self) {
        _preferencesController = preferencesController; // TODO: why?
        _folderColorController = [[SMFolderColorController alloc] initWithUserAccount:self];
        _mailbox = [[SMAccountMailbox alloc] initWithUserAccount:self];
        _localFolderRegistry = [[SMLocalFolderRegistry alloc] initWithUserAccount:self];
        _messageListController = [[SMMessageListController alloc] initWithUserAccount:self];
        _searchController = [[SMAccountSearchController alloc] initWithUserAccount:self];
        _mailboxController = [[SMAccountMailboxController alloc] initWithUserAccount:self];
        _outboxController = [[SMOutboxController alloc] initWithUserAccount:self];
        _operationExecutor = [[SMOperationExecutor alloc] initWithUserAccount:self];
        _backgroundMessageBodyFetchQueue = [[SMMessageBodyFetchQueue alloc] initWithUserAccount:self];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFetchQueueEmpty:) name:@"MessageBodyFetchQueueEmpty" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFetchQueueNotEmpty:) name:@"MessageBodyFetchQueueNotEmpty" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageHeadersSyncFinished:) name:@"MessageHeadersSyncFinished" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageCheckPeriodChanged:) name:@"MessageCheckPeriodChanged" object:nil];
    }
    
    SM_LOG_DEBUG(@"user account '%@' initialized", _accountName);
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)idleEnabled:(SMFolderKind)folderKind {
    if(_preferencesController.messageCheckPeriodSec != 0) {
        SM_LOG_INFO(@"user account '%@': IDLE disabled in user preferences", _accountName);
        return NO;
    }

    if(!_imapServerCapabilities || !_imapSession) {
        SM_LOG_INFO(@"user account '%@': no connection, IDLE not activated", _accountName);
        return NO;
    }
    
    if(![_imapServerCapabilities containsIndex:MCOIMAPCapabilityId]) {
        SM_LOG_INFO(@"user account '%@': IDLE not supported", _accountName);
        return NO;
    }
    
    if(_imapSession.maximumConnections < 2) {
        SM_LOG_INFO(@"user account '%@': too few connections (%u) allowed, IDLE disabled", _accountName, _imapSession.maximumConnections);
        return NO;
    }
    
    if(folderKind != SMFolderKindInbox && _imapSession.maximumConnections < 3) {
        SM_LOG_INFO(@"user account '%@': too few connections (%u) allowed, IDLE disabled for non-INBOX folder", _accountName, _imapSession.maximumConnections);
        return NO;
    }
    
    return YES;
}

- (void)messageCheckPeriodChanged:(NSNotification *)notification {
    [_inboxUpdateController scheduleFolderUpdate:YES];
}

- (void)messageFetchQueueEmpty:(NSNotification*)notification {
    SMMessageBodyFetchQueue *queue;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchQueueEmptyParams:(NSNotification*)notification queue:&queue account:&account];
    
    if(account == self) {
        // If the current folder message body fetch queue is empty, background fetch should be activated.
        if(queue == [(SMLocalFolder*)_messageListController.currentLocalFolder messageBodyFetchQueue]) {
            [_backgroundMessageBodyFetchQueue resumeBodyFetchQueue];
        }
    }
}

- (void)messageFetchQueueNotEmpty:(NSNotification*)notification {
    SMMessageBodyFetchQueue *queue;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchQueueNotEmptyParams:(NSNotification*)notification queue:&queue account:&account];
    
    if(account == self) {
        // If the current folder message body fetch queue is not empty, background fetch should be paused.
        if(queue == [(SMLocalFolder*)_messageListController.currentLocalFolder messageBodyFetchQueue]) {
            [_backgroundMessageBodyFetchQueue pauseBodyFetchQueue];
        }
    }
}

- (void)messageHeadersSyncFinished:(NSNotification *)notification {
    SMLocalFolder *localFolder;
    BOOL updateNow;
    BOOL hasUpdates;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageHeadersSyncFinishedParams:notification localFolder:&localFolder updateNow:&updateNow hasUpdates:&hasUpdates account:&account];
    
    if(account == self && !account.unified && localFolder.kind == SMFolderKindInbox) {
        [_inboxUpdateController scheduleFolderUpdate:updateNow];
    }
}

- (void)initSession:(NSUInteger)accountIdx {
    // Init the account data directory.
    NSURL *accountDirURL = [_preferencesController accountDirURL:accountIdx];
    
    SM_LOG_INFO(@"Account %lu data directory: %@", accountIdx, accountDirURL.path);

    NSError *dirCreateError;
    if(![[NSFileManager defaultManager] createDirectoryAtURL:accountDirURL withIntermediateDirectories:YES attributes:nil error:&dirCreateError]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Exit application"];
        [alert setMessageText:@"Unable to create application directory"];
        [alert setInformativeText:[NSString stringWithFormat:@"Error creating directory %@. %@", accountDirURL.path, dirCreateError.localizedDescription]];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert runModal];

        [NSApp terminate:nil];
    }

    // Init the database.
    NSString *databaseFilePath = [_preferencesController databaseFilePath:accountIdx];
    _database = [[SMDatabase alloc] initWithFilePath:databaseFilePath];
    
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
    
    // Cancel previously scheduled reachability notifier
    if(_inboxUpdateController) {
        [_inboxUpdateController cancelScheduledFolderUpdate];
        _inboxUpdateController = nil;
    }
    
    // Init the SMTP server.
    _smtpSession = [[MCOSMTPSession alloc] init];
    
    [_smtpSession setHostname:[_preferencesController smtpServer:accountIdx]];
    [_smtpSession setPort:[_preferencesController smtpPort:accountIdx]];
    [_smtpSession setCheckCertificateEnabled:[_preferencesController smtpNeedCheckCertificate:accountIdx]];
    
//    _smtpSession.connectionLogger = ^(void *connectionID, MCOConnectionLogType type, NSData *data) {
//        SM_LOG_NOISE(@"SMTP connection id: %p, bytes: %lu, type: %s", connectionID, data != nil? data.length : 0, mcoConnectionTypeName(type));
//    };
    
    MCOAuthType smtpAuthType = [SMPreferencesController smToMCOAuthType:[_preferencesController smtpAuthType:accountIdx]];
    if(smtpAuthType == MCOAuthTypeXOAuth2 || smtpAuthType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_smtpSession setOAuth2Token:@""];
    }
    
    [_smtpSession setAuthType:smtpAuthType];
    [_smtpSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[_preferencesController smtpConnectionType:accountIdx]]];
    [_smtpSession setUsername:[_preferencesController smtpUserName:accountIdx]];
    [_smtpSession setPassword:[_preferencesController smtpPassword:accountIdx]];
    
//    _imapSession.connectionLogger = ^(void *connectionID, MCOConnectionLogType type, NSData *data) {
//        SM_LOG_NOISE(@"IMAP connection id: %p, bytes: %lu, type: %s", connectionID, data != nil? data.length : 0, mcoConnectionTypeName(type));
//    };
    
    [self reloadAccount:accountIdx];
}

- (void)reloadAccount:(NSUInteger)accountIdx {
    _accountName = [_preferencesController accountName:accountIdx];
    
    NSString *fullUserName = [_preferencesController fullUserName:accountIdx];
    NSString *userEmail = [_preferencesController userEmail:accountIdx];
    
    _accountAddress = [[SMAddress alloc] initWithFullName:fullUserName email:userEmail representationMode:SMAddressRepresentation_FirstNameFirst];
    
    [self initAccountImage:accountIdx];
}

- (void)initAccountImage:(NSUInteger)accountIdx {
    if([_preferencesController useAddressBookAccountImage:accountIdx]) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        _accountImage = [appDelegate.addressBookController loadPictureForAddress:_accountAddress searchNetwork:NO allowWebSiteImage:NO tag:0 completionBlock:nil];
    }
    else {
        NSString *accountImagePath = [_preferencesController accountImagePath:accountIdx];
        _accountImage = [[NSImage alloc] initWithContentsOfFile:accountImagePath];
    }
    
    if(_accountImage == nil) {
        _accountImage = [SMAccountImageSelection defaultImage];
    }
}

- (void)initOpExecutor {
    [_mailboxController initFolders];
    
    SMUserAccount __weak *weakSelf = self;

    // TODO: use the resulting dbOp
    [_database loadOpQueue:@"SMTPQueue" block:^(SMDatabaseOp *op, SMOperationQueue *smtpQueue) {
        SMUserAccount *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        // TODO: use the resulting dbOp
        [_self->_database loadOpQueue:@"IMAPQueue" block:^(SMDatabaseOp *op, SMOperationQueue *imapQueue) {
            [_self processLoadOpeQueueResult:imapQueue smtpQueue:smtpQueue];
        }];
    }];
}

- (void)processLoadOpeQueueResult:(SMOperationQueue*)imapQueue smtpQueue:(SMOperationQueue*)smtpQueue {
    [imapQueue setOperationExecutorForPendingOps:_operationExecutor];
    [smtpQueue setOperationExecutorForPendingOps:_operationExecutor];
    
    [_operationExecutor setSmtpQueue:smtpQueue imapQueue:imapQueue];
    
    [_outboxController loadSMTPQueue:smtpQueue postSendAction:^(SMOpSendMessage *op) {
        [self->_outboxController finishMessageSending:op.outgoingMessage];
    }];
}

- (void)printImapServerCapabilities:(MCOIndexSet*)capabilities {
    SM_LOG_INFO(@"IMAP server capabilities:");
    
    if([capabilities containsIndex:MCOIMAPCapabilityACL]) {
        SM_LOG_INFO(@"ACL supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityBinary]) {
        SM_LOG_INFO(@"Binary supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityCatenate]) {
        SM_LOG_INFO(@"Catenate supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityChildren]) {
        SM_LOG_INFO(@"Children supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityCompressDeflate]) {
        SM_LOG_INFO(@"CompressDeflate supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityCondstore]) {
        SM_LOG_INFO(@"Condstore supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityEnable]) {
        SM_LOG_INFO(@"Enable supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityIdle]) {
        SM_LOG_INFO(@"Idle supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityId]) {
        SM_LOG_INFO(@"Id supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityLiteralPlus]) {
        SM_LOG_INFO(@"LiteralPlus supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityMove]) {
        SM_LOG_INFO(@"Move supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityMultiAppend]) {
        SM_LOG_INFO(@"MultiAppend supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityNamespace]) {
        SM_LOG_INFO(@"Namespace supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityQResync]) {
        SM_LOG_INFO(@"QResync supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityQuota]) {
        SM_LOG_INFO(@"Quota supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilitySort]) {
        SM_LOG_INFO(@"Sort supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityStartTLS]) {
        SM_LOG_INFO(@"StartTLS supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityThreadOrderedSubject]) {
        SM_LOG_INFO(@"ThreadOrderedSubject supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityThreadReferences]) {
        SM_LOG_INFO(@"ThreadReferences supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityUIDPlus]) {
        SM_LOG_INFO(@"UIDPlus supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityUnselect]) {
        SM_LOG_INFO(@"Unselect supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityXList]) {
        SM_LOG_INFO(@"XList supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthAnonymous]) {
        SM_LOG_INFO(@"AuthAnonymous supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthCRAMMD5]) {
        SM_LOG_INFO(@"AuthCRAMMD5 supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthDigestMD5]) {
        SM_LOG_INFO(@"AuthDigestMD5 supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthExternal]) {
        SM_LOG_INFO(@"AuthExternal supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthGSSAPI]) {
        SM_LOG_INFO(@"AuthGSSAPI supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthKerberosV4]) {
        SM_LOG_INFO(@"AuthKerberosV4 supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthLogin]) {
        SM_LOG_INFO(@"AuthLogin supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthNTLM]) {
        SM_LOG_INFO(@"AuthNTLM supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthOTP]) {
        SM_LOG_INFO(@"AuthOTP supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthPlain]) {
        SM_LOG_INFO(@"AuthPlain supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthSKey]) {
        SM_LOG_INFO(@"AuthSKey supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityAuthSRP]) {
        SM_LOG_INFO(@"AuthSRP supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityXOAuth2]) {
        SM_LOG_INFO(@"XOAuth2 supported");
    }
    if([capabilities containsIndex:MCOIMAPCapabilityGmail]) {
        SM_LOG_INFO(@"Gmail supported");
    }
}

- (void)getIMAPServerCapabilities {
    if(_capabilitiesOp != nil) {
        [_capabilitiesOp cancel];
        _capabilitiesOp = nil;
    }
    
    MCOIMAPCapabilityOperation *capabilitiesOp = [_imapSession capabilityOperation];
    
    void (^opBlock)(NSError*, MCOIndexSet*) = nil;
    
    SMUserAccount __weak *weakSelf = self;
    opBlock = ^(NSError * error, MCOIndexSet * capabilities) {
        SMUserAccount *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        if(_self->_capabilitiesOp != capabilitiesOp) {
            SM_LOG_WARNING(@"stale capabilities op ignored");
            return;
        }

        if(error) {
            SM_LOG_ERROR(@"error getting IMAP capabilities: %@", error);
            
            [_self->_capabilitiesOp start:opBlock];
        } else {
            [_self printImapServerCapabilities:capabilities];
            
            SM_LOG_INFO(@"IMAP server folder concurrent access is %@, maximum %u connections allowed", _self->_imapSession.allowsFolderConcurrentAccessEnabled? @"ENABLED" : @"DISABLED", _self->_imapSession.maximumConnections);
            
            _self->_imapServerCapabilities = capabilities;
            _self->_capabilitiesOp = nil;
            
            // Previous scheduleMessageListUpdate might not be able
            // to start because the server capabilities were not know.
            // So schedule it up right now.
            [_self->_inboxUpdateController scheduleFolderUpdate:NO];
        }
    };

    [capabilitiesOp start:opBlock];

    _capabilitiesOp = capabilitiesOp;
}

- (BOOL)imapServerAvailable {
    return _imapServerCapabilities != nil? YES : NO;
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
    
    // TODO: fetch inline attachments on demand
    // TODO: refresh current view of the message loaded from DB without attachments
    for(MCOAttachment *attachment in attachments) {
        // TODO: async operation
        NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
        NSData *attachmentData = [attachment data];
        
        SM_LOG_DEBUG(@"message uid %u, attachment unique id %@, contentID %@, body %@", uid, [attachment uniqueID], attachmentContentId, attachment);
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        NSURL *attachmentUrl = [appDelegate.attachmentStorage attachmentLocation:attachmentContentId uid:uid folder:remoteFolder account:self];
        
        NSError *err;
        if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
            SM_LOG_DEBUG(@"stored attachment exists at '%@'", attachmentUrl);
            continue;
        }
        
        if(attachmentData) {
            [appDelegate.attachmentStorage storeAttachment:attachmentData folder:remoteFolder uid:uid contentId:attachmentContentId filename:attachment.filename account:self];
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
            SMUserAccount __weak *weakSelf = self;
            [op start:^(NSError * error, NSData * data) {
                SMUserAccount *_self = weakSelf;
                if(!_self) {
                    SM_LOG_WARNING(@"object is gone");
                    return;
                }
                
                if (error.code == MCOErrorNone) {
                    NSAssert(data, @"no data");
                    
                    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
                    [appDelegate.attachmentStorage storeAttachment:data folder:remoteFolder uid:uid contentId:imapPart.contentID filename:imapPart.filename account:_self];
                } else {
                    SM_LOG_ERROR(@"Error downloading message body for msg uid %u, part unique id %@: %@", uid, partId, error);
                }
            }];
        }
    }
}

- (void)ensureMainLocalFoldersCreated {
    for(SMFolder *folder in _mailbox.mainFolders) {
        if([_localFolderRegistry getLocalFolderByName:folder.fullName] == nil) {
            if(folder.kind == SMFolderKindOutbox) {
                // TODO: workaround for possible "Outbox" folder name collision
                [_localFolderRegistry createLocalFolder:folder.fullName remoteFolder:nil kind:folder.kind initialUnreadCount:folder.initialUnreadCount syncWithRemoteFolder:NO];
            }
            else {
                SMLocalFolder *newLocalFolder = (SMLocalFolder*)[_localFolderRegistry createLocalFolder:folder.fullName remoteFolder:folder.fullName kind:folder.kind initialUnreadCount:folder.initialUnreadCount syncWithRemoteFolder:YES];
                
                if(folder.kind == SMFolderKindInbox) {
                    _inboxUpdateController = [[SMFolderUpdateController alloc] initWithUserAccount:self folder:newLocalFolder];
                }
            }
        }
    }
}

- (void)stopAccount {
    // For the given account, we need to do the following actions:
    //
    // 1. Ask to close all open editors with changes
    // 2. Close any message thread windows
    // 3. Stop all local folders sync
    // 4. Cancel and clear any pending ops in the IMAP and SMTP queues
 
    NSArray<id<SMAbstractLocalFolder>> *localFolders = _localFolderRegistry.localFolders;
    
    for(id<SMAbstractLocalFolder> localFolder in localFolders) {
        [localFolder stopLocalFolderSync:YES];
    }
    
    [_operationExecutor cancelAllOperations];
    
    //
    SM_LOG_WARNING(@"TODO");
    //
}

@end
