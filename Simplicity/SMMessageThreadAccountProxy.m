//
//  SMMessageThreadAccountProxy.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAbstractAccount.h"
#import "SMAbstractLocalFolder.h"
#import "SMFolderColorController.h"
#import "SMMessageThread.h"
#import "SMMessageStorage.h"
#import "SMMessageListController.h"
#import "SMMessageThreadAccountProxy.h"

@implementation SMMessageThreadAccountProxy

- (void)setMessageUnseen:(SMMessageThread*)messageThread message:(SMMessage*)message unseen:(Boolean)unseen {
    id<SMAbstractLocalFolder> localFolder = [[[messageThread.messageStorage account] messageListController] currentLocalFolder];
    [localFolder setMessageUnseen:message unseen:unseen];
}

- (void)setMessageFlagged:(SMMessageThread*)messageThread message:(SMMessage*)message flagged:(Boolean)flagged {
    id<SMAbstractLocalFolder> localFolder = [[[messageThread.messageStorage account] messageListController] currentLocalFolder];
    [localFolder setMessageFlagged:message flagged:flagged];
}

- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels {
    return [[[messageThread.messageStorage account] folderColorController] colorsForMessageThread:messageThread folder:folder labels:labels];
}

@end
