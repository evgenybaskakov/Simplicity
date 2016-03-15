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

+ (void)localNotifyFolderListUpdated {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FolderListUpdated" object:nil userInfo:nil];
}

+ (void)localNotifyMessageHeadersSyncFinished:(NSString *)localFolder hasUpdates:(BOOL)hasUpdates {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", nil]];
}

+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:localFolder, [NSNumber numberWithUnsignedInteger:uid], [NSNumber numberWithUnsignedLongLong:threadId], nil] forKeys:[NSArray arrayWithObjects:@"LocalFolderName", @"UID", @"ThreadId", nil]]];
}

+ (void)localNotifyMessageBodyLoaded:(uint32_t)uid {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyLoaded" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:uid], @"UID", nil]];
}

+ (void)localNotifyMessageFlagsUpdates:(NSString *)localFolder {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageFlagsUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", nil]];
}

+ (void)localNotifyMessagesUpdated:(NSString *)localFolder updateResult:(NSUInteger)updateResult {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessagesUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localFolder, @"LocalFolderName", [NSNumber numberWithUnsignedInteger:updateResult], @"UpdateResult", nil]];
}

+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController *)messageEditorViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteEditedMessageDraft" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageEditorViewController, @"MessageEditorViewController", nil]];
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

+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:messageThreadCellViewController, @"ThreadCell", replyKind, @"ReplyKind", toAddress, @"ToAddress", nil]];
}

+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageSent" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"MessageEditorViewController", nil]];
}

+ (void)localNotifyNewLabelCreated:(NSString*)labelName {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewLabelCreated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:labelName, @"LabelName", nil]];
}

#pragma mark Notification parameter getters

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }

    if(hasUpdates) {
        NSNumber *hasUpdatesNumber = [[notification userInfo] objectForKey:@"HasUpdates"];
        *hasUpdates = [hasUpdatesNumber boolValue];
    }
}

+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId {
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
}

+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }
}

+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(localFolder) {
        *localFolder = [messageInfo objectForKey:@"LocalFolderName"];
    }
}

+ (void)getMessageBodyLoadedParams:(NSNotification *)notification uid:(uint32_t *)uid {
    NSDictionary *messageInfo = [notification userInfo];
    
    if(uid) {
        *uid = [[messageInfo objectForKey:@"UID"] unsignedIntValue];
    }
}

@end
