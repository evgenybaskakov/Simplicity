//
//  SMNotificationsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMEditorReplyKind.h"

@class SMAddress;
@class SMUserAccount;
@class SMLocalFolder;
@class SMMessageEditorViewController;
@class SMMessageThreadCellViewController;
@class SMMessageBodyFetchQueue;

@interface SMNotificationsController : NSObject

+ (void)systemNotifyNewMessage:(NSString*)from;
+ (void)systemNotifyNewMessages:(NSUInteger)count;

+ (void)localNotifyAccountPreferencesChanged:(SMUserAccount*)account;
+ (void)localNotifyAccountSyncError:(SMUserAccount*)account error:(NSError*)error;
+ (void)localNotifyFolderListUpdated:(SMUserAccount*)account;
+ (void)localNotifyMessageHeadersSyncFinished:(SMLocalFolder*)localFolder scheduleUpdate:(BOOL)scheduleUpdate hasUpdates:(BOOL)hasUpdates account:(SMUserAccount*)account;
+ (void)localNotifyMessageBodyFetched:(SMLocalFolder*)localFolder messageId:(uint64_t)messageId threadId:(int64_t)threadId account:(SMUserAccount*)account;
+ (void)localNotifyMessageBodyFetchQueueEmpty:(SMMessageBodyFetchQueue*)queue account:(SMUserAccount*)account;
+ (void)localNotifyMessageBodyFetchQueueNotEmpty:(SMMessageBodyFetchQueue*)queue account:(SMUserAccount*)account;
+ (void)localNotifyMessageFlagsUpdates:(SMLocalFolder*)localFolder account:(SMUserAccount*)account;
+ (void)localNotifyMessagesUpdated:(SMLocalFolder*)localFolder updateResult:(NSUInteger)updateResult account:(SMUserAccount*)account;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(SMUserAccount*)account;
+ (void)localNotifyMessageViewFrameLoaded:(uint64_t)messageId account:(SMUserAccount*)account;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController account:(SMUserAccount*)account;
+ (void)localNotifyDiscardMessageDraft:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(SMEditorReplyKind)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getAccountPreferencesChangedParams:(NSNotification*)notification account:(SMUserAccount**)account;
+ (void)getAccountSyncErrorParams:(NSNotification*)notification error:(NSError**)error account:(SMUserAccount**)account;
+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder scheduleUpdate:(BOOL*)scheduleUpdate hasUpdates:(BOOL*)hasUpdates account:(SMUserAccount**)account;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder messageId:(uint64_t*)messageId threadId:(int64_t*)threadId account:(SMUserAccount**)account;
+ (void)getMessageBodyFetchQueueEmptyParams:(NSNotification*)notification queue:(SMMessageBodyFetchQueue**)queue account:(SMUserAccount**)account;
+ (void)getMessageBodyFetchQueueNotEmptyParams:(NSNotification*)notification queue:(SMMessageBodyFetchQueue**)queue account:(SMUserAccount**)account;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder account:(SMUserAccount**)account;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(SMLocalFolder**)localFolder account:(SMUserAccount**)account;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification messageId:(uint64_t*)messageId account:(SMUserAccount**)account;
+ (void)getFolderListUpdatedParams:(NSNotification*)notification account:(SMUserAccount**)account;

@end
