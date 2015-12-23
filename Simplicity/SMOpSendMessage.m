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
#import "SMMessageBuilder.h"
#import "SMOutgoingMessage.h"
#import "SMOpSendMessage.h"

@implementation SMOpSendMessage {
    SMOutgoingMessage *_outgoingMessage;
}

- (id)initWithOutgoingMessage:(SMOutgoingMessage*)outgoingMessage {
    self = [super initWithKind:kSMTPOpKind];
    
    if(self) {
        _outgoingMessage = outgoingMessage;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        SMMessageBuilder *messageBuilder = [coder decodeObjectForKey:@"_messageBuilder"];
        
        _outgoingMessage = [[SMOutgoingMessage alloc] initWithMessageBuilder:messageBuilder];
        
        // TODO: sync up the outbox folder
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_outgoingMessage.messageBuilder forKey:@"_messageBuilder"];
}

- (void)start {
    NSData *messageData = _outgoingMessage.messageBuilder.mcoMessageBuilder.data;
    NSAssert(messageData, @"no message data");
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOSMTPOperation *op = [[[appDelegate model] smtpSession] sendOperationWithData:messageData];
    
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
