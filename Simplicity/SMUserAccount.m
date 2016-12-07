//
//  SMUserAccount.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "Reachability.h"

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
#import "SMUserAccount.h"

static const NSUInteger AUTO_MESSAGE_CHECK_PERIOD_SEC = 60;

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
    Reachability *_imapServerReachability;
    MCOIndexSet *_imapServerCapabilities;
    MCOIMAPCapabilityOperation *_capabilitiesOp;
    MCOIMAPIdleOperation *_idleOp;
    NSInteger _idleId;
    NSString *_idleFolder;
}

@synthesize unified = _unified;
@synthesize attachmentStorage = _attachmentStorage;
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
        _attachmentStorage = [[SMAttachmentStorage alloc] initWithUserAccount:self];
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountSyncError:) name:@"AccountSyncError" object:nil];
    }
    
    SM_LOG_DEBUG(@"user account '%@' initialized", _accountName);
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)accountSyncError:(NSNotification*)notification {
    NSError *error;
    SMUserAccount *account;
    
    [SMNotificationsController getAccountSyncErrorParams:notification error:&error account:&account];
    
    NSAssert(account != nil, @"account is nil");
    NSAssert(error != nil, @"error is nil");
    
    BOOL severeError;
    switch(error.code) {
        case MCOErrorTLSNotAvailable:
        case MCOErrorCertificate:
        case MCOErrorAuthentication:
        case MCOErrorGmailIMAPNotEnabled:
        case MCOErrorMobileMeMoved:
        case MCOErrorYahooUnavailable:
        case MCOErrorStartTLSNotAvailable:
        case MCOErrorNeedsConnectToWebmail:
        case MCOErrorAuthenticationRequired:
        case MCOErrorInvalidAccount:
        case MCOErrorCompression:
        case MCOErrorGmailApplicationSpecificPasswordRequired:
        case MCOErrorServerDate:
        case MCOErrorNoValidServerFound:
            severeError = YES;
            break;
            
        default:
            severeError = NO;
            break;
    }
    
    if(severeError) {
        NSString *errorDesc = [SMStringUtils trimString:error.localizedDescription];
        if(errorDesc.length == 0) {
            errorDesc = @"Unknown server error occurred.";
        }
        else if([errorDesc characterAtIndex:errorDesc.length-1] != '.') {
            errorDesc = [errorDesc stringByAppendingString:@"."];
        }
        
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"Dismiss"];
        [alert addButtonWithTitle:@"Properties"];
        [alert setMessageText:[NSString stringWithFormat:@"There was a problem accessing your accout \"%@\"", account.accountName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ Error code %ld.\n\nPlease choose either to open account preferences, or dismiss this message.", errorDesc, error.code]];
        [alert setAlertStyle:NSCriticalAlertStyle];
        
        if([alert runModal] == NSAlertSecondButtonReturn) {
            // Exit the alert modal loop first.
            // Easiest way is to dispatch the request to the main thread queue.
            dispatch_async(dispatch_get_main_queue(), ^{
                SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
                [[appDelegate appController] showPreferencesWindowAction:YES accountName:account.accountName];
            });
        }
    }
    else {
        if(_imapServerReachability) {
            [_imapServerReachability stopNotifier];
        }
        
        NSString *imapServer = _imapSession.hostname;
        
        _imapServerReachability = [Reachability reachabilityWithHostname:imapServer];
        
        __weak id weakSelf = self;
        _imapServerReachability.reachableBlock = ^(Reachability *reachability) {
            SMUserAccount *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if(_self->_imapServerReachability != reachability) {
                    SM_LOG_WARNING(@"stale reachability object for IMAP server %@", imapServer);
                    return;
                }

                [_self->_imapServerReachability stopNotifier];
                _self->_imapServerReachability = nil;

                SM_LOG_INFO(@"IMAP server %@ is now reachable", imapServer);
                
                [_self scheduleMessageListUpdate];
            });
        };
        
        [_imapServerReachability startNotifier];
    }
}

- (BOOL)idleSupported {
    if(!_imapServerCapabilities ||
       !_imapSession)
    {
        SM_LOG_INFO(@"user account '%@': no connection, IDLE not activated", _accountName);
        return NO;
    }

    if(![_imapServerCapabilities containsIndex:MCOIMAPCapabilityId] ||
       _imapSession.maximumConnections <= 1)
    {
        SM_LOG_INFO(@"user account '%@': IDLE not supported", _accountName);
        return NO;
    }
    
    SM_LOG_INFO(@"user account '%@': IDLE is supported", _accountName);
    return YES;
}

- (BOOL)idleEnabled {
    return _preferencesController.messageCheckPeriodSec == 0 && self.idleSupported;
}

- (void)messageFetchQueueEmpty:(NSNotification*)notification {
    SMMessageBodyFetchQueue *queue;
    SMUserAccount *account;
    
    [SMNotificationsController getMessageBodyFetchQueueEmptyParams:(NSNotification*)notification queue:&queue account:&account];
    
    if(account == self) {
        // If the current folder message body fetch queue is empty, background fetch should be activated.
        if(queue == [(SMLocalFolder*)_messageListController.currentLocalFolder messageBodyFetchQueue]) {
            if(self.idleEnabled) {
                [self startIdle];
            }

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
            if(self.idleEnabled) {
                [self stopIdle];
            }
            
            [_backgroundMessageBodyFetchQueue pauseBodyFetchQueue];
        }
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
    if(_imapServerReachability) {
        [_imapServerReachability stopNotifier];
        _imapServerReachability = nil;
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
    NSAssert(_capabilitiesOp == nil, @"_capabilitiesOp is not nil");
    
    _capabilitiesOp = [_imapSession capabilityOperation];
    
    void (^opBlock)(NSError*, MCOIndexSet*) = nil;
    
    SMUserAccount __weak *weakSelf = self;
    opBlock = ^(NSError * error, MCOIndexSet * capabilities) {
        SMUserAccount *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
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
            [_self scheduleMessageListUpdate];
        }
    };
    
    [_capabilitiesOp start:opBlock];
}

- (void)scheduleMessageListUpdate {
    if(_imapServerCapabilities == nil) {
        SM_LOG_INFO(@"IMAP server capabilities not yet known, postponing message list update");
        return;
    }
        
    if(self.idleEnabled) {
        [self startIdle];
    }
    else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startMessagesUpdate) object:nil];

        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        NSUInteger updateIntervalSec = [[appDelegate preferencesController] messageCheckPeriodSec];
        
        if(updateIntervalSec == 0) {
            updateIntervalSec = AUTO_MESSAGE_CHECK_PERIOD_SEC;
        }
        
        SM_LOG_DEBUG(@"scheduling message list update after %lu sec", updateIntervalSec);
        
        [self performSelector:@selector(startMessagesUpdate) withObject:nil afterDelay:updateIntervalSec];
    }
}

- (void)cancelScheduledMessagesUpdate {
    if(self.idleEnabled) {
        [self stopIdle];
    }
    else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startMessagesUpdate) object:nil];
    }
}

- (void)startMessagesUpdate {
    [_messageListController startMessagesUpdate];
}

- (void)startIdle {
    if(_idleOp != nil) {
        // This happens when the control message check is finished
        // as we just enabled the idle operation.
        SM_LOG_DEBUG(@"idle operation is already running");
        return;
    }
    
    SMLocalFolder *currentLocalFolder = (SMLocalFolder*)_messageListController.currentLocalFolder;
    
    if(currentLocalFolder.syncedWithRemoteFolder) {
        _idleFolder = currentLocalFolder.remoteFolderName;
    }
    else {
        // Otherwise just watch the Inbox.
        _idleFolder = [[_mailbox inboxFolder] fullName];
    }
    
    NSUInteger idleId = ++_idleId;
    SM_LOG_INFO(@"new IDLE operation is running for folder '%@', id %lu", _idleFolder, idleId);
    
    SMUserAccount __weak *weakSelf = self;
    void (^opBlock)(NSError *) = ^(NSError *error) {
        SMUserAccount *_self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        
        if(idleId != _self->_idleId) {
            SM_LOG_INFO(@"stale idle operation dismissed, id %lu", idleId);
            return;
        }
        
        if(error && error.code != MCOErrorNone) {
            SM_LOG_ERROR(@"IDLE operation error for folder '%@', id %lu: %@", _self->_idleFolder, _self->_idleId, error);
        }
        else {
            SM_LOG_INFO(@"IDLE operation triggers for '%@', id %lu", _self->_idleFolder, _self->_idleId);
        }

        _self->_idleOp = nil;
        _self->_idleFolder = nil;
        
        // In any case, just sync the messages.
        // Any connectivity errors will be handled alongside.
        [_self startMessagesUpdate];
    };
    
    _idleOp = [_imapSession idleOperationWithFolder:_idleFolder lastKnownUID:0];
    [_idleOp start:opBlock];
    
    // After the idle op is started, we must check if there are any changes happened.
    // If we don't then there's a time gap between the last sync and the idle start,
    // i.e. we're at risk to miss something.
    [self startMessagesUpdate];
}

- (void)stopIdle {
    if(_idleOp != nil) {
        SM_LOG_INFO(@"cancelling IDLE operation for folder '%@', id %lu", _idleFolder, _idleId);

        [_idleOp cancel];
        
        _idleOp = nil;
        _idleFolder = nil;
    }
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
        NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
        NSData *attachmentData = [attachment data];
        
        SM_LOG_DEBUG(@"message uid %u, attachment unique id %@, contentID %@, body %@", uid, [attachment uniqueID], attachmentContentId, attachment);
        
        NSURL *attachmentUrl = [_attachmentStorage attachmentLocation:attachmentContentId uid:uid folder:remoteFolder];
        
        NSError *err;
        if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
            SM_LOG_DEBUG(@"stored attachment exists at '%@'", attachmentUrl);
            continue;
        }
        
        if(attachmentData) {
            [_attachmentStorage storeAttachment:attachmentData folder:remoteFolder uid:uid contentId:attachmentContentId];
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
                    
                    [_self->_attachmentStorage storeAttachment:data folder:remoteFolder uid:uid contentId:imapPart.contentID];
                } else {
                    SM_LOG_ERROR(@"Error downloading message body for msg uid %u, part unique id %@: %@", uid, partId, error);
                }
            }];
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
