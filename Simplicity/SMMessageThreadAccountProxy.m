//
//  SMMessageThreadAccountProxy.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMUserAccount.h"
#import "SMAbstractLocalFolder.h"
#import "SMFolderColorController.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageListController.h"
#import "SMMessageThreadAccountProxy.h"

@implementation SMMessageThreadAccountProxy

- (void)setMessageUnseen:(SMMessageThread*)messageThread message:(SMMessage*)message unseen:(Boolean)unseen {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    [localFolder setMessageUnseen:message unseen:unseen];
}

- (void)setMessageFlagged:(SMMessageThread*)messageThread message:(SMMessage*)message flagged:(Boolean)flagged {
    id<SMAbstractLocalFolder> localFolder = [[messageThread.account messageListController] currentLocalFolder];
    [localFolder setMessageFlagged:message flagged:flagged];
}

- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels {
    return [[messageThread.account folderColorController] colorsForMessageThread:messageThread folder:folder labels:labels];
}

- (void)fetchMessageBodyUrgently:(SMMessageThread*)messageThread uid:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName {
    [[messageThread.messageStorage localFolder] fetchMessageBodyUrgentlyWithUID:uid messageId:messageId messageDate:messageDate remoteFolder:remoteFolderName threadId:messageThread.threadId];
}

@end
