//
//  SMOpDeleteMessages.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpDeleteMessages.h"

@implementation SMOpDeleteMessages {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    MCOIMAPOperation *_currentOp;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName {
    self = [super init];

    if(self) {
        _uids = uids;
        _remoteFolderName = remoteFolderName;
    }

    return self;
}

- (void)start {
    [self startInternal];
}

- (void)cancel {
    [self cancelInternal];
}

- (void)startInternal {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeFlagsOperationWithFolder:_remoteFolderName uids:_uids kind:MCOIMAPStoreFlagsRequestKindSet flags:MCOMessageFlagDeleted];
    
    _currentOp = op;
    
    [op start:^(NSError * error) {
        if(error == nil) {
            NSLog(@"%s: Flags for remote folder %@ successfully updated", __func__, _remoteFolderName);
            
            [self expungeInternal];
        } else {
            NSLog(@"%s: Error updating flags for remote folder %@: %@", __func__, _remoteFolderName, error);
            
            [self startInternal];
        }
    }];
}

- (void)expungeInternal {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");

    MCOIMAPOperation *op = [session expungeOperation:_remoteFolderName];

    _currentOp = op;

    [op start:^(NSError *error) {
        if(error == nil) {
            NSLog(@"%s: Remote folder %@ successfully expunged", __func__, _remoteFolderName);

            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            SMMessageListController *messageListController = [[appDelegate model] messageListController];

            // TODO: should check if the current folder is the same as expunged one

            [messageListController scheduleMessageListUpdate:YES];
        } else {
            NSLog(@"%s: Error expunging remote folder %@: %@", __func__, _remoteFolderName, error);
            
            [self expungeInternal];
        }
    }];
}

- (void)cancelInternal {
    [_currentOp cancel];
    _currentOp = nil;
}

@end
