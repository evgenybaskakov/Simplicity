//
//  SMOpAddLabel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpAddLabel.h"

@implementation SMOpAddLabel {
    MCOIndexSet *_uids;
    NSString *_remoteFolderName;
    NSString *_label;
    MCOIMAPOperation *_currentOp;
}

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName label:(NSString*)label {
    self = [super init];
    
    if(self) {
        _uids = uids;
        _remoteFolderName = remoteFolderName;
        _label = label;
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
    
    MCOIMAPOperation *op = [session storeLabelsOperationWithFolder:_remoteFolderName uids:_uids kind:MCOIMAPStoreFlagsRequestKindAdd labels:[NSArray arrayWithObject:_label]];

    _currentOp = op;

    [op start:^(NSError * error) {
        if(error == nil) {
            NSLog(@"%s: Label %@ for folder %@ successfully set", __func__, _label, _remoteFolderName);

            [self complete];
        } else {
            NSLog(@"%s: Error setting label %@ for folder %@: %@", __func__, _label, _remoteFolderName, error);
            
            [self startInternal];
        }
    }];
}

- (void)cancelInternal {
    [_currentOp cancel];
    _currentOp = nil;
}

@end
