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

+ (void)localNotifyAccountSyncError:(NSObject<SMAbstractAccount>*)account error:(NSString*)error;
+ (void)localNotifyFolderListUpdated:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessageHeadersSyncFinished:(NSString*)localFolder hasUpdates:(BOOL)hasUpdates account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessageFlagsUpdates:(NSString*)localFolder account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessagesUpdated:(NSString*)localFolder updateResult:(NSUInteger)updateResult account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid account:(NSObject<SMAbstractAccount>*)account;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController account:(NSObject<SMAbstractAccount>*)account;

+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getAccountSyncErrorParams:(NSNotification*)notification error:(NSString**)error account:(NSObject<SMAbstractAccount>**)account;
+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates account:(NSObject<SMAbstractAccount>**)account;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId account:(NSObject<SMAbstractAccount>**)account;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(NSObject<SMAbstractAccount>**)account;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(NSObject<SMAbstractAccount>**)account;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification uid:(uint32_t*)uid account:(NSObject<SMAbstractAccount>**)account;
+ (void)getFolderListUpdatedParams:(NSNotification*)notification account:(NSObject<SMAbstractAccount>**)account;

@end
