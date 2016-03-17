//
//  SMOpSetMessageFlags.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/5/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMOperationExecutor.h"
#import "SMOpSetMessageFlags.h"

@implementation SMOpSetMessageFlags {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    MCOIMAPStoreFlagsRequestKind _requestKind;
    MCOMessageFlag _flags;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName kind:(MCOIMAPStoreFlagsRequestKind)kind flags:(MCOMessageFlag)flags operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kIMAPOpKind operationExecutor:operationExecutor];
    
    if(self) {
        _uids = uids;
        _remoteFolderName = remoteFolderName;
        _requestKind = kind;
        _flags = flags;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _uids = [coder decodeObjectForKey:@"_uids"];
        _remoteFolderName = [coder decodeObjectForKey:@"_remoteFolderName"];
        _requestKind = (MCOIMAPStoreFlagsRequestKind)[coder decodeIntegerForKey:@"_requestKind"];
        _flags = (MCOMessageFlag)[coder decodeIntegerForKey:@"_flags"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_uids forKey:@"_uids"];
    [coder encodeObject:_remoteFolderName forKey:@"_remoteFolderName"];
    [coder encodeInteger:_requestKind forKey:@"_requestKind"];
    [coder encodeInteger:_flags forKey:@"_flags"];
}

- (void)start {
    MCOIMAPSession *session = [[_operationExecutor.account model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeFlagsOperationWithFolder:_remoteFolderName uids:_uids kind:_requestKind flags:_flags];

    self.currentOp = op;
    
    [op start:^(NSError * error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Message flags set in remote folder %@", _remoteFolderName);
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error setting message flags in remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Set message flags";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Setting message flags in folder %@", _remoteFolderName];
}

@end
