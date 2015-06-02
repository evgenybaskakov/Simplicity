//
//  SMOutboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/26/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMOpSendMessage.h"
#import "SMOutboxController.h"

@implementation SMOutboxController

- (void)sendMessage:(MCOMessageBuilder*)message {
	NSLog(@"%s", __func__);
    
    SMOpSendMessage *op = [[SMOpSendMessage alloc] initWithMessage:message];
    [op start]; // TODO: queue!!!
}

@end
