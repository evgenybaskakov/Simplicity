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
#import "SMOpSendMessage.h"

@implementation SMOpSendMessage {
    SMMessageBuilder *_messageBuilder;
}

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder {
    self = [super initWithKind:kSMTPOpKind];
    
    if(self) {
        _messageBuilder = messageBuilder;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _messageBuilder = [coder decodeObjectForKey:@"_messageBuilder"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_messageBuilder forKey:@"_messageBuilder"];
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOSMTPOperation *op = [[[appDelegate model] smtpSession] sendOperationWithData:_messageBuilder.mcoMessageBuilder.data];
    
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
