//
//  SMOpAppendMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMOpAppendMessage.h"

@implementation SMOpAppendMessage {
    MCOMessageBuilder *_message;
    NSString *_remoteFolderName;
}

- (id)initWithMessage:(MCOMessageBuilder*)message remoteFolderName:(NSString*)remoteFolderName {
    self = [super initWithKind:kIMAPChangeOpKind];

    if(self) {
        _message = message;
        _remoteFolderName = remoteFolderName;
    }
    
    return self;
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPAppendMessageOperation *op = [session appendMessageOperationWithFolder:_remoteFolderName messageData:_message.data flags:MCOMessageFlagNone customFlags:nil];

    self.currentOp = op;
    
    [op start:^(NSError * error, uint32_t createdUID) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");

        if(error == nil) {
            SM_LOG_DEBUG(@"Message appended to remote folder %@, new uid %u", _remoteFolderName, createdUID);

            if(_postActionTarget) {
                NSDictionary *messageInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_message, [NSNumber numberWithUnsignedInteger:createdUID], nil] forKeys:[NSArray arrayWithObjects:@"Message", @"UID", nil]];
                
                [_postActionTarget performSelector:_postActionSelector withObject:messageInfo afterDelay:0];
            }

            [self complete];
        } else {
            SM_LOG_ERROR(@"Error updating flags for remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Append message";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Appending message to folder %@", _remoteFolderName];
}

@end
