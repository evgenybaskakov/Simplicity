//
//  SMMessageBuilder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/27/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAttachmentItem.h"
#import "SMMessageBuilder.h"

@implementation SMMessageBuilder

+ (MCOMessageBuilder*)createMessage:(NSString*)messageText subject:(NSString*)subject to:(NSString*)to cc:(NSString*)cc bcc:(NSString*)bcc fromMailbox:(NSString*)fromMailbox attachmentItems:(NSArray*)attachmentItems {
    NSAssert(messageText, @"messageText is nil");
    NSAssert(subject, @"subject is nil");
    NSAssert(to, @"to is nil");
    NSAssert(cc, @"cc is nil");
    NSAssert(bcc, @"bcc is nil");
    
    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
    
    //TODO: custom from
    [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"Evgeny Baskakov" mailbox:fromMailbox]];
    
    // TODO: form an array of addresses and names based on _toField contents
    NSArray *toAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:to mailbox:to]];
    [[builder header] setTo:toAddresses];
    
    // TODO: form an array of addresses and names based on _ccField contents
    NSArray *ccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:cc mailbox:cc]];
    [[builder header] setCc:ccAddresses];
    
    // TODO: form an array of addresses and names based on _bccField contents
    NSArray *bccAddresses = [NSArray arrayWithObject:[MCOAddress addressWithDisplayName:bcc mailbox:bcc]];
    [[builder header] setBcc:bccAddresses];
    
    // TODO: check subject length, issue a warning if empty
    [[builder header] setSubject:subject];
    
    //TODO (send plain text): [(DOMHTMLElement *)[[[webView mainFrame] DOMDocument] documentElement] outerText];
    
    [builder setHTMLBody:messageText];
    
    //TODO (local attachments): [builder addAttachment:[MCOAttachment attachmentWithContentsOfFile:@"/Users/foo/Pictures/image.jpg"]];
    
    for(SMAttachmentItem *attachmentItem in attachmentItems) {
        MCOAttachment *mcoAttachment = nil;
        
        if(attachmentItem.fileData != nil) {
            mcoAttachment = [MCOAttachment attachmentWithData:attachmentItem.fileData filename:attachmentItem.fileName];
        }
        else {
            NSString *attachmentLocalFilePath = attachmentItem.localFilePath;
            NSAssert(attachmentLocalFilePath != nil, @"attachmentLocalFilePath is nil");
            
            mcoAttachment = [MCOAttachment attachmentWithContentsOfFile:attachmentLocalFilePath];
        }
        
        [builder addAttachment:mcoAttachment];
        // TODO: ???    - (void) addRelatedAttachment:(MCOAttachment *)attachment;
    }
    
    return builder;
}

+ (NSData*)serializeMessage:(MCOMessageBuilder*)messageBuilder {
    SM_LOG_ERROR(@"TODO");
    return nil;
}

+ (MCOMessageBuilder*)deserializeMessage:(NSData*)data {
    SM_LOG_ERROR(@"TODO");
    return nil;
}

@end
