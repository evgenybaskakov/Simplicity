//
//  SMOpSendMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMOpSendMessage.h"

@implementation SMOpSendMessage {
    MCOMessageBuilder *_message;
}

- (id)initWithMessage:(MCOMessageBuilder*)message {
    self = [super initWithKind:kSMTPOpKind];
    
    if(self) {
        _message = message;
    }
    
    return self;
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOSMTPOperation *op = [[[appDelegate model] smtpSession] sendOperationWithData:_message.data];
    
    self.currentOp = op;
    
    [op start:^(NSError * error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if (error == nil || [error code] == MCOErrorNone) {
            SM_LOG_DEBUG(@"message sent successfully");
        
            if(self.postActionTarget) {
                [self.postActionTarget performSelector:self.postActionSelector withObject:nil afterDelay:0];
            }
            
            [self complete];
        }
        else {
            SM_LOG_ERROR(@"Error sending message: %@", error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Send messages";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Sending 1 message"];
}

@end
