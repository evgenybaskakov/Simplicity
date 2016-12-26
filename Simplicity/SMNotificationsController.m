//
//  SMNotificationsController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"
#import "SMUserAccount.h"
#import "SMLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageStorage.h"
#import "SMMessageThread.h"
#import "SMMessage.h"
#import "SMAddress.h"

@implementation SMNotificationsController

- (id)init {
    self = [super init];
    
    if(self) {
        [[NSUserNotificationCenter defaultUserNotificationCenter]  setDelegate:self];
    }
    
    return self;
}

- (void)dealloc {
    [[NSUserNotificationCenter defaultUserNotificationCenter]  setDelegate:nil];
}

- (void)systemNotifyNewMessage:(SMMessage*)message localFolder:(SMLocalFolder*)localFolder {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(preferencesController.shouldShowNotifications) {
        NSString *from = message.fromAddress.stringRepresentationShort;
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        
        notification.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLongLong:message.messageId], @"MessageId", localFolder.localName, @"LocalFolder", ((SMUserAccount*)localFolder.account).accountName, @"AccountName", nil];

        notification.title = @"New message";
        notification.informativeText = [NSString stringWithFormat:@"From %@", from];
        notification.soundName = nil; // TODO: NSUserNotificationDefaultSoundName;
        notification.actionButtonTitle = (preferencesController.defaultReplyAction == SMDefaultReplyAction_Reply ? @"Reply" : @"Reply All");
        notification.otherButtonTitle = @"Delete";
        notification.hasActionButton = YES;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

- (void)systemNotifyNewMessages:(NSUInteger)count {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(preferencesController.shouldShowNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        
        notification.title = [NSString stringWithFormat:@"%lu new messages", count];
//        notification.informativeText = previewText;
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

#pragma mark Local notifications

+ (void)localNotifyAccountPreferencesChanged:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountPreferencesChanged" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", nil]];
}

+ (void)localNotifyAccountSyncSuccess:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountSyncSuccess" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", nil]];
}

+ (void)localNotifyAccountSyncError:(SMUserAccount*)account error:(NSError*)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountSyncError" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", error, @"Error", nil]];
}

+ (void)localNotifyFolderListUpdated:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FolderListUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", nil]];
}

+ (void)localNotifyMessageHeadersSyncFinished:(SMLocalFolder*)localFolder updateNow:(BOOL)updateNow hasUpdates:(BOOL)hasUpdates account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderInstance", [NSNumber numberWithBool:updateNow], @"UpdateNow", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", account, @"Account", nil]];
}

+ (void)localNotifyMessageBodyFetched:(SMLocalFolder*)localFolder messageId:(uint64_t)messageId threadId:(int64_t)threadId account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderInstance", [NSNumber numberWithUnsignedInteger:messageId], @"messageId", [NSNumber numberWithUnsignedLongLong:threadId], @"ThreadId", account, @"Account", nil]];
}

+ (void)localNotifyMessageBodyFetchQueueEmpty:(SMMessageBodyFetchQueue*)queue account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetchQueueEmpty" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:queue, @"Queue", account, @"Account", nil]];
}

+ (void)localNotifyMessageBodyFetchQueueNotEmpty:(SMMessageBodyFetchQueue*)queue account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetchQueueNotEmpty" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:queue, @"Queue", account, @"Account", nil]];
}

+ (void)localNotifyMessageFlagsUpdates:(SMLocalFolder*)localFolder account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageFlagsUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderInstance", account, @"Account", nil]];
}

+ (void)localNotifyMessagesUpdated:(SMLocalFolder*)localFolder updateResult:(NSUInteger)updateResult account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessagesUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderInstance", [NSNumber numberWithUnsignedInteger:updateResult], @"UpdateResult", account, @"Account", nil]];
}

+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewLabelCreated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:labelName, @"LabelName", account, @"Account", nil]];
}

+ (void)localNotifyMessageViewFrameLoaded:(uint64_t)messageId account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageViewFrameLoaded" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLongLong:messageId], @"messageId", account, @"Account", nil]];
}

+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController *)messageEditorViewController account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteEditedMessageDraft" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageEditorViewController, @"MessageEditorViewController", account, @"Account", nil]];
}

#pragma mark Account biased notifications

+ (void)localNotifyDiscardMessageDraft:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DiscardMessageDraft" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChangeMessageFlaggedFlag" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChangeMessageUnreadFlag" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteMessage" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SaveAttachments" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SaveAttachmentsToDownloads" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", nil]];
}

+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(SMEditorReplyKind)replyKind toAddress:(SMAddress*)toAddress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", [NSNumber numberWithUnsignedInteger:replyKind], @"ReplyKind", toAddress, @"ToAddress", nil]];
}

#pragma mark Notification parameter getters

+ (void)getAccountPreferencesChangedParams:(NSNotification*)notification account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getAccountSyncSuccessParams:(NSNotification*)notification account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getAccountSyncErrorParams:(NSNotification*)notification error:(NSError**)error account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(error) {
        *error = [messageInfo objectForKey:@"Error"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder updateNow:(BOOL*)updateNow hasUpdates:(BOOL*)hasUpdates account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderInstance"];
    }

    if(updateNow) {
        NSNumber *updateNowNumber = [[notification userInfo] objectForKey:@"UpdateNow"];
        *updateNow = [updateNowNumber boolValue];
    }
    
    if(hasUpdates) {
        NSNumber *hasUpdatesNumber = [[notification userInfo] objectForKey:@"HasUpdates"];
        *hasUpdates = [hasUpdatesNumber boolValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder messageId:(uint64_t*)messageId threadId:(int64_t*)threadId account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderInstance"];
    }
    
    if(threadId) {
        *threadId = [[messageInfo objectForKey:@"ThreadId"] unsignedLongLongValue];
    }
    
    if(messageId) {
        *messageId = [[messageInfo objectForKey:@"messageId"] unsignedLongLongValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageBodyFetchQueueEmptyParams:(NSNotification*)notification queue:(SMMessageBodyFetchQueue**)queue account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];

    if(queue) {
        *queue = [messageInfo objectForKey:@"Queue"];
    }

    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageBodyFetchQueueNotEmptyParams:(NSNotification*)notification queue:(SMMessageBodyFetchQueue**)queue account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(queue) {
        *queue = [messageInfo objectForKey:@"Queue"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderInstance"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderInstance"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageViewFrameLoadedParams:(NSNotification *)notification messageId:(uint64_t*)messageId account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(messageId) {
        *messageId = [[messageInfo objectForKey:@"messageId"] unsignedLongLongValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getFolderListUpdatedParams:(NSNotification*)notification account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSNumber *messageId = [notification.userInfo objectForKey:@"MessageId"];
    NSString *localFolderName = [notification.userInfo objectForKey:@"LocalFolder"];
    NSString *accountName = [notification.userInfo objectForKey:@"AccountName"];

    SM_LOG_INFO(@"messageId %@, localFolder %@, accountName %@, activationType %ld", messageId, localFolderName, accountName, notification.activationType);
    
    if(messageId == nil || localFolderName == nil || accountName == nil) {
        return;
    }
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];

    NSUInteger accountIdx = [appDelegate accountIndexByName:accountName];
    if(accountIdx == NSNotFound) {
        return;
    }

    SMPreferencesController *preferencesController = [appDelegate preferencesController];

    if(notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
        // Reply button clicked
        SMEditorReplyKind replyKind = (preferencesController.defaultReplyAction == SMDefaultReplyAction_Reply ? SMEditorReplyKind_ReplyOne : SMEditorReplyKind_ReplyAll);
        
        SMUserAccount *account = appDelegate.accounts[accountIdx];
        SMLocalFolder *localFolder = (SMLocalFolder*)[account.localFolderRegistry getLocalFolderByName:localFolderName];
        SMMessage *message = [localFolder messageById:messageId.unsignedLongLongValue];
        
        if(message == nil) {
            return;
        }
        
        [appDelegate.appController composeReply:replyKind message:message account:account];
    }
    else if(notification.activationType == NSUserNotificationActivationTypeNone) {
        // Content clicked
        // TODO
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDismissAlert:(NSUserNotification *)notification {
    NSNumber *messageId = [notification.userInfo objectForKey:@"MessageId"];
    NSString *localFolderName = [notification.userInfo objectForKey:@"LocalFolder"];
    NSString *accountName = [notification.userInfo objectForKey:@"AccountName"];
    
    SM_LOG_INFO(@"messageId %@, localFolder %@, accountName %@, activationType %ld", messageId, localFolderName, accountName, notification.activationType);

    if(messageId == nil || localFolderName == nil || accountName == nil) {
        return;
    }
    
    if(notification.activationType == NSUserNotificationActivationTypeContentsClicked) {
        // Delete button clicked
        // TODO
    }
}

@end
