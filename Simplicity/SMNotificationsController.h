//
//  SMNotificationsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractAccount.h"

@class SMAddress;
@class SMMessageEditorViewController;
@class SMMessageThreadCellViewController;

@interface SMNotificationsController : NSObject

+ (void)systemNotifyNewMessage:(NSString*)from;
+ (void)systemNotifyNewMessages:(NSUInteger)count;

+ (void)localNotifyAccountSyncError:(id<SMAbstractAccount>)account error:(NSString*)error;
+ (void)localNotifyFolderListUpdated:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessageHeadersSyncFinished:(NSString*)localFolder hasUpdates:(BOOL)hasUpdates account:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId account:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessageFlagsUpdates:(NSString*)localFolder account:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessagesUpdated:(NSString*)localFolder updateResult:(NSUInteger)updateResult account:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController account:(id<SMAbstractAccount>)account;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(id<SMAbstractAccount>)account;
+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid account:(id<SMAbstractAccount>)account;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController account:(id<SMAbstractAccount>)account;

+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getAccountSyncErrorParams:(NSNotification*)notification error:(NSString**)error account:(id<SMAbstractAccount>*)account;
+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates account:(id<SMAbstractAccount>*)account;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId account:(id<SMAbstractAccount>*)account;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(id<SMAbstractAccount>*)account;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(id<SMAbstractAccount>*)account;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification uid:(uint32_t*)uid account:(id<SMAbstractAccount>*)account;
+ (void)getFolderListUpdatedParams:(NSNotification*)notification account:(id<SMAbstractAccount>*)account;

@end
