//
//  SMOpMoveMessages.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMMailbox.h"
#import "SMFolder.h"
#import "SMMessageListController.h"
#import "SMOpAddLabel.h"
#import "SMOpDeleteMessages.h"
#import "SMOpMoveMessages.h"

@implementation SMOpMoveMessages {
    MCOIndexSet *_uids;
    NSString *_srcRemoteFolderName;
    NSString *_dstRemoteFolderName;
    MCOIMAPOperation *_currentOp;
}

- (id)initWithUids:(MCOIndexSet*)uids srcRemoteFolderName:(NSString*)src dstRemoteFolderName:(NSString*)dst {
    self = [super init];
    
    if(self) {
        _uids = uids;
        _srcRemoteFolderName = src;
        _dstRemoteFolderName = dst;
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
    NSAssert(_uids.count > 0, @"no message uids to move from %@ to %@", _srcRemoteFolderName, _dstRemoteFolderName);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPCopyMessagesOperation *op = [session copyMessagesOperationWithFolder:_srcRemoteFolderName uids:_uids destFolder:_dstRemoteFolderName];
    
    op.urgent = YES;
    
    [op start:^(NSError *error, NSDictionary *uidMapping) {
        if(error == nil) {
            if(uidMapping != nil) {
                SMFolder *targetFolder = [[[appDelegate model] mailbox] getFolderByName:_dstRemoteFolderName];
                
                if(targetFolder != nil && targetFolder.kind == SMFolderKindRegular) {
                    MCOIndexSet *uids = [MCOIndexSet indexSet];
                    for(NSNumber *srcUid in uidMapping)
                        [uids addIndex:[[uidMapping objectForKey:srcUid] unsignedLongLongValue]];
                    
                    SMOpAddLabel *op = [[SMOpAddLabel alloc] initWithUids:_uids remoteFolderName:_dstRemoteFolderName label:_dstRemoteFolderName];
                    [op start]; // TODO: put in a queue
                }
            }
            
            SMOpDeleteMessages *op = [[SMOpDeleteMessages alloc] initWithUids:_uids remoteFolderName:_srcRemoteFolderName];
            [op start]; // TODO: put in a queue
        } else {
            NSLog(@"%s: Error copying messages from %@ to %@: %@", __func__, _srcRemoteFolderName, _dstRemoteFolderName, error);
        }
    }];
}

- (void)cancelInternal {
    [_currentOp cancel];
    _currentOp = nil;
}

@end
