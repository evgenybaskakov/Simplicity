//
//  SMOpAddLabel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpAddLabel.h"

@implementation SMOpAddLabel {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    NSString *_label;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName label:(NSString*)label {
    self = [super initWithKind:kIMAPChangeOpKind];
    
    if(self) {
        _uids = uids;
        _remoteFolderName = remoteFolderName;
        _label = label;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _uids = [coder decodeObjectForKey:@"_uids"];
        _remoteFolderName = [coder decodeObjectForKey:@"_remoteFolderName"];
        _label = [coder decodeObjectForKey:@"_label"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:_uids forKey:@"_uids"];
    [coder encodeObject:_remoteFolderName forKey:@"_remoteFolderName"];
    [coder encodeObject:_label forKey:@"_label"];
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeLabelsOperationWithFolder:_remoteFolderName uids:_uids kind:MCOIMAPStoreFlagsRequestKindAdd labels:[NSArray arrayWithObject:_label]];
    
    self.currentOp = op;
    
    [op start:^(NSError * error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Label %@ for folder %@ successfully set", _label, _remoteFolderName);
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error setting label %@ for folder %@: %@", _label, _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Add label";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Applying label %@ for %u messages in folder %@", _label, _uids.count, _remoteFolderName];
}

@end
