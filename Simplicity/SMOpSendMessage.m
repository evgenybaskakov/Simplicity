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
#import "SMUserAccount.h"
#import "SMOperationExecutor.h"
#import "SMMessageBuilder.h"
#import "SMOutgoingMessage.h"
#import "SMOpSendMessage.h"

@implementation SMOpSendMessage {
    SMOutgoingMessage *_outgoingMessage;
}

- (id)initWithOutgoingMessage:(SMOutgoingMessage*)outgoingMessage operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kSMTPOpKind operationExecutor:operationExecutor];
    
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
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_outgoingMessage.messageBuilder forKey:@"_messageBuilder"];
}

- (SMOutgoingMessage*)outgoingMessage {
    return _outgoingMessage;
}

- (void)start {
    NSData *messageData = _outgoingMessage.messageBuilder.mcoMessageBuilder.data;
    NSAssert(messageData, @"no message data");
    
    MCOSMTPOperation *op = [[(SMUserAccount*)_operationExecutor.account smtpSession] sendOperationWithData:messageData];
    
    self.currentOp = op;
    
    __weak id weakSelf = self;
    [op start:^(NSError *error) {
        id _self = weakSelf;
        if(!_self) {
            SM_LOG_WARNING(@"object is gone");
            return;
        }
        [_self processSendOpResult:error];
    }];
}

- (void)processSendOpResult:(NSError*)error {
    NSAssert(self.currentOp != nil, @"current op has disappeared");
    
    if (error == nil || error.code == MCOErrorNone) {
        SM_LOG_DEBUG(@"message sent successfully");
        
        if(self.postActionTarget) {
            [self.postActionTarget performSelector:self.postActionSelector withObject:_outgoingMessage afterDelay:0];
        }
        
        [self complete];
    }
    else {
        SM_LOG_ERROR(@"Error sending message: %@", error);
        
        [self fail];
    }
}

- (NSString*)name {
    return @"Send messages";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Sending 1 message"];
}

@end
