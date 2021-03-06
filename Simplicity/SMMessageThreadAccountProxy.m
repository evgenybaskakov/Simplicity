//
//  SMMessageThreadAccountProxy.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMUserAccount.h"
#import "SMMessage.h"
#import "SMAbstractLocalFolder.h"
#import "SMFolderColorController.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageListController.h"
#import "SMMessageThreadAccountProxy.h"

@implementation SMMessageThreadAccountProxy

- (BOOL)moveMessage:(SMMessageThread*)messageThread message:(SMMessage*)message toRemoteFolder:(NSString*)remoteFolder {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    return [localFolder moveMessage:message.messageId uid:message.uid toRemoteFolder:remoteFolder];
}

- (void)setMessageUnseen:(SMMessageThread*)messageThread message:(SMMessage*)message unseen:(BOOL)unseen {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    [localFolder setMessageUnseen:message unseen:unseen];
}

- (void)setMessageFlagged:(SMMessageThread*)messageThread message:(SMMessage*)message flagged:(BOOL)flagged {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    [localFolder setMessageFlagged:message flagged:flagged];
}

- (void)addMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    [localFolder addMessageThreadLabel:messageThread label:label];
}

- (BOOL)removeMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    return [localFolder removeMessageThreadLabel:messageThread label:label];
}

- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels {
    return [[messageThread.account folderColorController] colorsForMessageThread:messageThread folder:folder labels:labels];
}

- (void)fetchMessageBodyUrgently:(SMMessageThread*)messageThread uid:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName {
    [[messageThread.messageStorage localFolder] fetchMessageBodyUrgentlyWithUID:uid messageId:messageId messageDate:messageDate remoteFolder:remoteFolderName threadId:messageThread.threadId];
}

@end
