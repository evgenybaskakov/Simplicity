//
//  SMNotificationsController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"

@implementation SMNotificationsController

+ (void)systemNotifyNewMessage:(NSString*)from {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(preferencesController.shouldShowNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];

        notification.title = @"New message";
        notification.informativeText = [NSString stringWithFormat:@"From %@", from];
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

+ (void)systemNotifyNewMessages:(NSUInteger)count {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
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

+ (void)localNotifyAccountSyncError:(SMUserAccount*)account error:(NSError*)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountSyncError" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", error, @"Error", nil]];
}

+ (void)localNotifyFolderListUpdated:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FolderListUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", nil]];
}

+ (void)localNotifyMessageHeadersSyncFinished:(SMLocalFolder*)localFolder hasUpdates:(BOOL)hasUpdates account:(SMUserAccount*)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderInstance", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", account, @"Account", nil]];
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

+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", replyKind, @"ReplyKind", toAddress, @"ToAddress", nil]];
}

#pragma mark Notification parameter getters

+ (void)getAccountPreferencesChangedParams:(NSNotification*)notification account:(SMUserAccount**)account {
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

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder hasUpdates:(BOOL*)hasUpdates account:(SMUserAccount**)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderInstance"];
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

@end
