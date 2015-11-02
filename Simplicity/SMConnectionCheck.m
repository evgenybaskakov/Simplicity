//
//  SMConnectionCheck.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/1/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMConnectionCheck.h"

@implementation SMConnectionCheck

- (void)checkImapConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    MCOIMAPSession *session = [[MCOIMAPSession alloc] init];
    
    [session setPort:[preferencesController imapPort:accountIdx]];
    [session setHostname:[preferencesController imapServer:accountIdx]];
    [session setConnectionType:[SMPreferencesController smToMCOConnectionType:[preferencesController imapConnectionType:accountIdx]]];
    [session setAuthType:[SMPreferencesController smToMCOAuthType:[preferencesController imapAuthType:accountIdx]]];
    [session setUsername:[preferencesController imapUserName:accountIdx]];
    [session setPassword:[preferencesController imapPassword:accountIdx]];

     MCOIMAPOperation *op = [session checkAccountOperation];
     [op start:^(NSError *error) {
         if(error == nil || error.code == MCOErrorNone) {
             SM_LOG_INFO(@"IMAP server connected ok");
             
             statusBlock(SMConnectionStatus_Connected, MCOErrorNone);
         }
         else {
             SM_LOG_ERROR(@"IMAP connection error %lu: '%@'", error.code, error);
             
             statusBlock(SMConnectionStatus_ConnectionFailed, error.code);
         }
     }];
}

- (void)checkSmtpConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    MCOSMTPSession *session = [[MCOSMTPSession alloc] init];
    
    [session setPort:[preferencesController smtpPort:accountIdx]];
    [session setHostname:[preferencesController smtpServer:accountIdx]];
    [session setConnectionType:[SMPreferencesController smToMCOConnectionType:[preferencesController smtpConnectionType:accountIdx]]];
    [session setAuthType:[SMPreferencesController smToMCOAuthType:[preferencesController smtpAuthType:accountIdx]]];
    [session setUsername:[preferencesController smtpUserName:accountIdx]];
    [session setPassword:[preferencesController smtpPassword:accountIdx]];
    
    MCOAddress *fromAddress = [MCOAddress addressWithMailbox:[preferencesController userEmail:accountIdx]];
    MCOSMTPOperation *op = [session checkAccountOperationWithFrom:fromAddress];
    [op start:^(NSError *error) {
        if(error == nil || error.code == MCOErrorNone) {
            SM_LOG_INFO(@"SMTP server connected ok");
            
            statusBlock(SMConnectionStatus_Connected, MCOErrorNone);
        }
        else {
            SM_LOG_ERROR(@"SMTP connection error %lu: '%@'", error.code, error);
            
            statusBlock(SMConnectionStatus_ConnectionFailed, error.code);
        }
    }];
}

@end
