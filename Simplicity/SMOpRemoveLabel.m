//
//  SMOpRemoveLabel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMOperationExecutor.h"
#import "SMMessageListController.h"
#import "SMOpRemoveLabel.h"

@implementation SMOpRemoveLabel {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    NSString *_label;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName label:(NSString*)label operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kIMAPOpKind operationExecutor:operationExecutor];
    
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
    MCOIMAPSession *session = [(SMUserAccount*)_operationExecutor.account imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session storeLabelsOperationWithFolder:_remoteFolderName uids:_uids kind:MCOIMAPStoreFlagsRequestKindRemove labels:@[_label]];
    
    self.currentOp = op;
    
    [op start:^(NSError * error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Label %@ for folder %@ successfully removed", _label, _remoteFolderName);
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error removing label %@ for folder %@: %@", _label, _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Remove label";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Removing label %@ from %u messages in folder %@", _label, _uids.count, _remoteFolderName];
}

@end
