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

+ (void)localNotifyAccountSyncError:(id<SMAbstractAccount>)account error:(NSString*)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AccountSyncError" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", error, @"Error", nil]];
}

+ (void)localNotifyFolderListUpdated:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FolderListUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:account, @"Account", nil]];
}

+ (void)localNotifyMessageHeadersSyncFinished:(NSString *)localFolder hasUpdates:(BOOL)hasUpdates account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", account, @"Account", nil]];
}

+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", [NSNumber numberWithUnsignedInteger:uid], @"UID", [NSNumber numberWithUnsignedLongLong:threadId], @"ThreadId", account, @"Account", account, @"Account", nil]];
}

+ (void)localNotifyMessageFlagsUpdates:(NSString *)localFolder account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageFlagsUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", account, @"Account", nil]];
}

+ (void)localNotifyMessagesUpdated:(NSString *)localFolder updateResult:(NSUInteger)updateResult account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessagesUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", [NSNumber numberWithUnsignedInteger:updateResult], @"UpdateResult", account, @"Account", nil]];
}

+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewLabelCreated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:labelName, @"LabelName", account, @"Account", nil]];
}

+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageSent" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"MessageEditorViewController", account, @"Account", nil]];
}

+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid account:(id<SMAbstractAccount>)account {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageViewFrameLoaded" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:uid], @"UID", account, @"Account", nil]];
}

+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController *)messageEditorViewController account:(id<SMAbstractAccount>)account {
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

+ (void)getAccountSyncErrorParams:(NSNotification*)notification error:(NSString**)error account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(error) {
        *error = [messageInfo objectForKey:@"Error"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }

    if(hasUpdates) {
        NSNumber *hasUpdatesNumber = [[notification userInfo] objectForKey:@"HasUpdates"];
        *hasUpdates = [hasUpdatesNumber boolValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }
    
    if(threadId) {
        *threadId = [[messageInfo objectForKey:@"ThreadId"] unsignedLongLongValue];
    }
    
    if(uid) {
        *uid = [[messageInfo objectForKey:@"UID"] unsignedIntValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getMessageViewFrameLoadedParams:(NSNotification *)notification uid:(uint32_t *)uid account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(uid) {
        *uid = [[messageInfo objectForKey:@"UID"] unsignedIntValue];
    }
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

+ (void)getFolderListUpdatedParams:(NSNotification*)notification account:(id<SMAbstractAccount>*)account {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(account) {
        *account = [messageInfo objectForKey:@"Account"];
    }
}

@end
