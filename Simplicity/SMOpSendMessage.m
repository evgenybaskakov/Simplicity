//
//  SMOpSendMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMOpSendMessage.h"

@implementation SMOpSendMessage {
    MCOMessageBuilder *_message;
    MCOSMTPOperation *_currentOp;
}

- (id)initWithMessage:(MCOMessageBuilder*)message {
    self = [super init];
    
    if(self) {
        _message = message;
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
    MCOSMTPOperation *op = [[[appDelegate model] smtpSession] sendOperationWithData:_message.data];
    
    _currentOp = op;
    
    [op start:^(NSError * error) {
        if (error != nil && [error code] != MCOErrorNone) {
            NSLog(@"%s: Error sending message: %@", __func__, error);
            
            [self startInternal];
        } else {
            NSLog(@"%s: message sent successfully", __func__);
            
            [self complete];
        }
    }];
}

- (void)cancelInternal {
    [_currentOp cancel];
    _currentOp = nil;
}

@end
