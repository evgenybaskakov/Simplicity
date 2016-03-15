//
//  SMNotificationsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMAddress;
@class SMMessageEditorViewController;
@class SMMessageThreadCellViewController;

@interface SMNotificationsController : NSObject

+ (void)systemNotifyNewMessage:(NSString*)from;
+ (void)systemNotifyNewMessages:(NSUInteger)count;

+ (void)localNotifyFolderListUpdated:(NSUInteger)accountIdx;
+ (void)localNotifyMessageHeadersSyncFinished:(NSString*)localFolder hasUpdates:(BOOL)hasUpdates accountIdx:(NSUInteger)accountIdx;
+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId accountIdx:(NSUInteger)accountIdx;
+ (void)localNotifyMessageFlagsUpdates:(NSString*)localFolder accountIdx:(NSUInteger)accountIdx;
+ (void)localNotifyMessagesUpdated:(NSString*)localFolder updateResult:(NSUInteger)updateResult accountIdx:(NSUInteger)accountIdx;
+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController accountIdx:(NSUInteger)accountIdx;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName accountIdx:(NSUInteger)accountIdx;

+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController;
+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates accountIdx:(NSUInteger*)accountIdx;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId accountIdx:(NSUInteger*)accountIdx;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder accountIdx:(NSUInteger*)accountIdx;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder accountIdx:(NSUInteger*)accountIdx;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification uid:(uint32_t*)uid accountIdx:(NSUInteger*)accountIdx;

@end
