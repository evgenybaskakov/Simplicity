//
//  SMOpMoveMessages.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMUserAccount.h"
#import "SMAccountMailbox.h"
#import "SMFolder.h"
#import "SMMessageListController.h"
#import "SMOperationExecutor.h"
#import "SMOpAddLabel.h"
#import "SMOpDeleteMessages.h"
#import "SMOpMoveMessages.h"

@implementation SMOpMoveMessages {
    MCOIndexSet *_uids;
    NSString *_srcRemoteFolderName;
    NSString *_dstRemoteFolderName;
}

- (id)initWithUids:(MCOIndexSet*)uids srcRemoteFolderName:(NSString*)src dstRemoteFolderName:(NSString*)dst operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kIMAPOpKind operationExecutor:operationExecutor];
    
    if(self) {
        _uids = uids;
        _srcRemoteFolderName = src;
        _dstRemoteFolderName = dst;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _uids = [coder decodeObjectForKey:@"_uids"];
        _srcRemoteFolderName = [coder decodeObjectForKey:@"_srcRemoteFolderName"];
        _dstRemoteFolderName = [coder decodeObjectForKey:@"_dstRemoteFolderName"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_uids forKey:@"_uids"];
    [coder encodeObject:_srcRemoteFolderName forKey:@"_srcRemoteFolderName"];
    [coder encodeObject:_dstRemoteFolderName forKey:@"_dstRemoteFolderName"];
}

- (void)start {
    NSAssert(_uids.count > 0, @"no message uids to move from %@ to %@", _srcRemoteFolderName, _dstRemoteFolderName);
    
    MCOIMAPSession *session = [_operationExecutor.account imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPCopyMessagesOperation *op = [session copyMessagesOperationWithFolder:_srcRemoteFolderName uids:_uids destFolder:_dstRemoteFolderName];
    
    op.urgent = YES;
    
    self.currentOp = op;
    
    [op start:^(NSError *error, NSDictionary *uidMapping) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            if(uidMapping != nil) {
                SMFolder *targetFolder = [[_operationExecutor.account mailbox] getFolderByName:_dstRemoteFolderName];

                if(targetFolder != nil && targetFolder.kind == SMFolderKindRegular) {
                    MCOIndexSet *uids = [MCOIndexSet indexSet];
                    for(NSNumber *srcUid in uidMapping)
                        [uids addIndex:[[uidMapping objectForKey:srcUid] unsignedLongLongValue]];
                    
                    SMOpAddLabel *op = [[SMOpAddLabel alloc] initWithUids:_uids remoteFolderName:_dstRemoteFolderName label:_dstRemoteFolderName operationExecutor:_operationExecutor];

                    [op enqueue];
                }
            }
            
            SMOpDeleteMessages *op = [[SMOpDeleteMessages alloc] initWithUids:_uids remoteFolderName:_srcRemoteFolderName operationExecutor:_operationExecutor];
            
            [self replaceWith:op];
        } else {
            SM_LOG_ERROR(@"Error copying messages from %@ to %@: %@", _srcRemoteFolderName, _dstRemoteFolderName, error);

            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Move messages";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Moving %u messages from %@ to %@", _uids.count, _srcRemoteFolderName, _dstRemoteFolderName];
}

@end
