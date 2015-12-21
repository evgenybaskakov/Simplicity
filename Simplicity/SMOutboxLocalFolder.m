//
//  SMOutboxLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/19/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMOutboxLocalFolder.h"

@implementation SMOutboxLocalFolder

- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen {
    SM_FATAL(@"Message cannot be set seen/unseen in Outbox folder");
}

- (void)setMessageFlagged:(SMMessage *)message flagged:(Boolean)flagged {
    SM_FATAL(@"Message cannot be set flagged/unflagged in Outbox folder");
}

@end
