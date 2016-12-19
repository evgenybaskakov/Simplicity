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
#import "SMFolderKind.h"

@class SMPreferencesController;
@class SMOperationExecutor;
@class SMMessageBodyFetchQueue;
@class SMMessage;

@class MCOIMAPSession;
@class MCOSMTPSession;

@interface SMUserAccount : NSObject<SMAbstractAccount>

@property (readonly) BOOL imapServerAvailable;

@property MCOIMAPSession *imapSession;
@property MCOSMTPSession *smtpSession;

@property (readonly) SMOperationExecutor *operationExecutor;
@property (readonly) SMMessageBodyFetchQueue *backgroundMessageBodyFetchQueue;

- (id)initWithPreferencesController:(SMPreferencesController*)preferencesController;
- (void)initSession:(NSUInteger)accountIdx;
- (void)initOpExecutor;
- (void)getIMAPServerCapabilities;
- (void)ensureMainLocalFoldersCreated;
- (void)stopAccount;
- (void)reloadAccount:(NSUInteger)accountIdx;
- (BOOL)idleEnabled:(SMFolderKind)folderKind;

@end
