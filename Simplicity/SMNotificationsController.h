//
//  SMNotificationsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMAddress;
@class SMAccountDescriptor;
@class SMMessageEditorViewController;
@class SMMessageThreadCellViewController;

@interface SMNotificationsController : NSObject

+ (void)systemNotifyNewMessage:(NSString*)from;
+ (void)systemNotifyNewMessages:(NSUInteger)count;

+ (void)localNotifyFolderListUpdated:(NSUInteger)account;
+ (void)localNotifyMessageHeadersSyncFinished:(NSString*)localFolder hasUpdates:(BOOL)hasUpdates account:(SMAccountDescriptor*)account;
+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId account:(SMAccountDescriptor*)account;
+ (void)localNotifyMessageFlagsUpdates:(NSString*)localFolder account:(SMAccountDescriptor*)account;
+ (void)localNotifyMessagesUpdated:(NSString*)localFolder updateResult:(NSUInteger)updateResult account:(SMAccountDescriptor*)account;
+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController account:(SMAccountDescriptor*)account;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(SMAccountDescriptor*)account;

+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController;
+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates account:(SMAccountDescriptor**)account;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId account:(SMAccountDescriptor**)account;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(SMAccountDescriptor**)account;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(SMAccountDescriptor**)account;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification uid:(uint32_t*)uid account:(SMAccountDescriptor**)account;

@end
