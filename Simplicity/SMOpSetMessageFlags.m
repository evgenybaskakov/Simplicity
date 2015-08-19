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
#import "SMOpSetMessageFlags.h"

@implementation SMOpSetMessageFlags {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    MCOIMAPStoreFlagsRequestKind _kind;
    MCOMessageFlag _flags;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName kind:(MCOIMAPStoreFlagsRequestKind)kind flags:(MCOMessageFlag)flags {
    self = [super initWithKind:kIMAPChangeOpKind];
    
    if(self) {
        _uids = uids;
        _remoteFolderName = remoteFolderName;
        _kind = kind;
        _flags = flags;
    }
    
    return self;
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeFlagsOperationWithFolder:_remoteFolderName uids:_uids kind:_kind flags:_flags];

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
