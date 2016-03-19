//
//  SMOpDeleteFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/10/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMOperationExecutor.h"
#import "SMAppController.h"
#import "SMMailboxViewController.h"
#import "SMOpDeleteFolder.h"

@implementation SMOpDeleteFolder {
    NSString *_remoteFolderName;
}

- (id)initWithRemoteFolder:(NSString*)remoteFolderName operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kIMAPOpKind operationExecutor:operationExecutor];
    
    if(self) {
        _remoteFolderName = remoteFolderName;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _remoteFolderName = [coder decodeObjectForKey:@"_remoteFolderName"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_remoteFolderName forKey:@"_remoteFolderName"];
}

- (NSString*)name {
    return @"Delete folder";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Deleting folder %@", _remoteFolderName];
}

- (void)start {
    MCOIMAPSession *session = [_operationExecutor.account imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session deleteFolderOperation:_remoteFolderName];
    
    self.currentOp = op;
    
    [op start:^(NSError *error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Remote folder %@ successfully deleted", _remoteFolderName);
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error deleting remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

@end
