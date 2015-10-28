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

+ (MCOMessageBuilder*)createMessage:(NSString*)messageText subject:(NSString*)subject from:(MCOAddress*)from to:(MCOAddress*)to cc:(MCOAddress*)cc bcc:(MCOAddress*)bcc attachmentItems:(NSArray*)attachmentItems {
    NSAssert(messageText, @"messageText is nil");
    NSAssert(subject, @"subject is nil");
    NSAssert(to, @"to is nil");
    NSAssert(cc, @"cc is nil");
    NSAssert(bcc, @"bcc is nil");
    
    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
    
    [[builder header] setFrom:from];
    
    // TODO: form an array of addresses and names based on _toField contents
    NSArray *toAddresses = [NSArray arrayWithObject:to];
    [[builder header] setTo:toAddresses];
    
    // TODO: form an array of addresses and names based on _ccField contents
    NSArray *ccAddresses = [NSArray arrayWithObject:cc];
    [[builder header] setCc:ccAddresses];
    
    // TODO: form an array of addresses and names based on _bccField contents
    NSArray *bccAddresses = [NSArray arrayWithObject:bcc];
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

- (id)initWithMessageText:(NSString*)messageText subject:(NSString*)subject from:(MCOAddress*)from to:(MCOAddress*)to cc:(MCOAddress*)cc bcc:(MCOAddress*)bcc attachmentItems:(NSArray*)attachmentItems {
    NSAssert(messageText, @"messageText is nil");
    NSAssert(subject, @"subject is nil");
    NSAssert(to, @"to is nil");
    NSAssert(cc, @"cc is nil");
    NSAssert(bcc, @"bcc is nil");
    
    self = [super init];
    
    if(self) {
        _mcoMessageBuilder = [SMMessageBuilder createMessage:messageText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:attachmentItems];
        _attachments = attachmentItems;
    }
    
    return self;
}

- (id)initWithMCOMessageBuilder:(MCOMessageBuilder*)mcoMessageBuilder attachments:(NSArray*)attachments {
    self = [super init];
    
    if(self) {
        _mcoMessageBuilder = mcoMessageBuilder;
        _attachments = attachments;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    
    if (self) {
        NSString *messageText = [coder decodeObjectForKey:@"messageText"];
        NSString *subject = [coder decodeObjectForKey:@"subject"];
        MCOAddress *from = [coder decodeObjectForKey:@"from"];
        MCOAddress *to = [coder decodeObjectForKey:@"to"];
        MCOAddress *cc = [coder decodeObjectForKey:@"cc"];
        MCOAddress *bcc = [coder decodeObjectForKey:@"bcc"];
        NSArray *attachmentItems = [coder decodeObjectForKey:@"attachmentItems"];
    
        _mcoMessageBuilder = [SMMessageBuilder createMessage:messageText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:attachmentItems];
        _attachments = attachmentItems;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:[_mcoMessageBuilder htmlBody] forKey:@"messageText"];
    [coder encodeObject:[[_mcoMessageBuilder header] subject] forKey:@"subject"];
    [coder encodeObject:[[_mcoMessageBuilder header] from] forKey:@"from"];
    [coder encodeObject:[[_mcoMessageBuilder header] to] forKey:@"to"];
    [coder encodeObject:[[_mcoMessageBuilder header] cc] forKey:@"cc"];
    [coder encodeObject:[[_mcoMessageBuilder header] bcc] forKey:@"bcc"];
    [coder encodeObject:_attachments forKey:@"attachmentItems"];
}

@end
