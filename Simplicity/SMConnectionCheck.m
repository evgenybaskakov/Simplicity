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

@implementation SMConnectionCheck {
    MCOIMAPSession *_imapSession;
    MCOIMAPOperation *_imapCheckOp;
    MCOSMTPSession *_smtpSession;
    MCOSMTPOperation *_smtpCheckOp;
}

- (void)checkImapConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock {
    if(_imapSession) {
        [_imapSession cancelAllOperations];
        
        [[_imapSession disconnectOperation] start:^(NSError *error) {
            if(error != nil && error.code != MCOErrorNone) {
                SM_LOG_ERROR(@"could not disconnect IMAP server: %@", error);
            }
        }];
        
        _imapSession = nil;
        _imapCheckOp = nil;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    _imapSession = [[MCOIMAPSession alloc] init];

    [_imapSession setPort:[preferencesController imapPort:accountIdx]];
    [_imapSession setHostname:[preferencesController imapServer:accountIdx]];
    [_imapSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[preferencesController imapConnectionType:accountIdx]]];
    
    MCOAuthType authType = [SMPreferencesController smToMCOAuthType:[preferencesController imapAuthType:accountIdx]];
    if(authType == MCOAuthTypeXOAuth2 || authType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_imapSession setOAuth2Token:@""];
    }
    
    [_imapSession setAuthType:authType];
    [_imapSession setUsername:[preferencesController imapUserName:accountIdx]];
    [_imapSession setPassword:[preferencesController imapPassword:accountIdx]];

    _imapCheckOp = [_imapSession checkAccountOperation];

    [_imapCheckOp start:^(NSError *error) {
         if(error == nil || error.code == MCOErrorNone) {
             SM_LOG_INFO(@"IMAP server connected ok");
             
             statusBlock(SMConnectionStatus_Connected, MCOErrorNone);
         }
         else {
             SM_LOG_ERROR(@"IMAP connection error %lu: '%@'", error.code, error);
             
             statusBlock(SMConnectionStatus_ConnectionFailed, error.code);
         }
        
        _imapSession = nil;
        _imapCheckOp = nil;
     }];
}

- (void)checkSmtpConnection:(NSUInteger)accountIdx statusBlock:(void (^)(SMConnectionStatus, MCOErrorCode))statusBlock {
    if(_smtpSession) {
        [_smtpSession cancelAllOperations];
        
        _smtpSession = nil;
        _smtpCheckOp = nil;
    }
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    _smtpSession = [[MCOSMTPSession alloc] init];
    
    [_smtpSession setPort:[preferencesController smtpPort:accountIdx]];
    [_smtpSession setHostname:[preferencesController smtpServer:accountIdx]];
    [_smtpSession setConnectionType:[SMPreferencesController smToMCOConnectionType:[preferencesController smtpConnectionType:accountIdx]]];
    
    MCOAuthType authType = [SMPreferencesController smToMCOAuthType:[preferencesController smtpAuthType:accountIdx]];
    if(authType == MCOAuthTypeXOAuth2 || authType == MCOAuthTypeXOAuth2Outlook) {
        // TODO: Workaround for not having OAuth2 token input means.
        [_smtpSession setOAuth2Token:@""];
    }
    
    [_smtpSession setAuthType:authType];
    [_smtpSession setUsername:[preferencesController smtpUserName:accountIdx]];
    [_smtpSession setPassword:[preferencesController smtpPassword:accountIdx]];
    
    MCOAddress *fromAddress = [MCOAddress addressWithMailbox:[preferencesController userEmail:accountIdx]];

    _smtpCheckOp = [_smtpSession checkAccountOperationWithFrom:fromAddress];

    [_smtpCheckOp start:^(NSError *error) {
        if(error == nil || error.code == MCOErrorNone) {
            SM_LOG_INFO(@"SMTP server connected ok");
            
            statusBlock(SMConnectionStatus_Connected, MCOErrorNone);
        }
        else {
            SM_LOG_ERROR(@"SMTP connection error %lu: '%@'", error.code, error);
            
            statusBlock(SMConnectionStatus_ConnectionFailed, error.code);
        }
        
        _smtpSession = nil;
        _smtpCheckOp = nil;
    }];
}

@end
