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
#import "SMOpExpungeFolder.h"
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
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeFlagsOperationWithFolder:_remoteFolderName uids:_uids kind:MCOIMAPStoreFlagsRequestKindSet flags:MCOMessageFlagDeleted];
    
    _currentOp = op;
    
    [op start:^(NSError * error) {
        if(error == nil) {
            NSLog(@"%s: Flags for remote folder %@ successfully updated", __func__, _remoteFolderName);
            
            SMOpExpungeFolder *op = [[SMOpExpungeFolder alloc] initWithRemoteFolder:_remoteFolderName];
            
            [self replaceWith:op];
        } else {
            NSLog(@"%s: Error updating flags for remote folder %@: %@", __func__, _remoteFolderName, error);
            
            [self start]; // repeat (TODO)
        }
    }];
}

- (void)cancel {
    [_currentOp cancel];
    _currentOp = nil;
}

@end
