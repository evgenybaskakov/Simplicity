//
//  SMUserAccount.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/14/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

#import "SMAbstractAccount.h"

@class SMPreferencesController;
@class SMOperationExecutor;
@class SMMessage;

@class MCOIMAPSession;
@class MCOSMTPSession;

@interface SMUserAccount : NSObject<SMAbstractAccount>

@property MCOIMAPSession *imapSession;
@property MCOSMTPSession *smtpSession;

@property (readonly) MCOIndexSet *imapServerCapabilities;
@property (readonly) SMOperationExecutor *operationExecutor;

- (id)initWithPreferencesController:(SMPreferencesController*)preferencesController;
- (void)initSession:(NSUInteger)accountIdx;
- (void)initOpExecutor;
- (void)getIMAPServerCapabilities;
- (void)stopAccount;

@end
