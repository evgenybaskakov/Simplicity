//
//  SMOpDeleteMessages.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpExpungeFolder.h"
#import "SMOpDeleteMessages.h"

@implementation SMOpDeleteMessages {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName {
    self = [super initWithKind:kIMAPChangeOpKind];

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
    
    self.currentOp = op;
    
    [op start:^(NSError * error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Flags for remote folder %@ successfully updated", _remoteFolderName);
            
            SMOpExpungeFolder *op = [[SMOpExpungeFolder alloc] initWithRemoteFolder:_remoteFolderName];
            
            [self replaceWith:op];
        } else {
            SM_LOG_ERROR(@"Error updating flags for remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Delete messages";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Deleting %u messages in folder %@", _uids.count, _remoteFolderName];
}

@end
