//
//  SMOpExpungeFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/4/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpExpungeFolder.h"

@implementation SMOpExpungeFolder {
    NSString *_remoteFolderName;
}

- (id)initWithRemoteFolder:(NSString*)remoteFolderName {
    self = [super initWithKind:kIMAPOpKind];
    
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

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session expungeOperation:_remoteFolderName];
    
    self.currentOp = op;
    
    [op start:^(NSError *error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Remote folder %@ successfully expunged", _remoteFolderName);
            
            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            SMMessageListController *messageListController = [[appDelegate model] messageListController];
            
            // TODO: should check if the current folder is the same as expunged one
            
            [messageListController scheduleMessageListUpdate:YES];
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error expunging remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Expunge folder";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Expunging folder %@", _remoteFolderName];
}

@end
