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

+ (MCOMessageBuilder*)createMessage:(NSString*)messageText plainText:(Boolean)plainText subject:(NSString*)subject from:(MCOAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc attachmentItems:(NSArray*)attachmentItems {
    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
    
    if(from != nil) {
        [[builder header] setFrom:from];
    }
    else {
        SM_LOG_WARNING(@"from is not set");
    }
    
    if(to != nil) {
        [[builder header] setTo:to];
    }
    else {
        SM_LOG_WARNING(@"to is not set");
    }
    
    if(cc != nil) {
        [[builder header] setCc:cc];
    }
    else {
        SM_LOG_WARNING(@"cc is not set");
    }

    if(bcc != nil) {
        [[builder header] setBcc:bcc];
    }
    else {
        SM_LOG_WARNING(@"bcc is not set");
    }

    if(subject != nil) {
        [[builder header] setSubject:subject];
    }
    else {
        SM_LOG_WARNING(@"subject is not set");
    }

    if(messageText != nil) {
        if(plainText) {
            [builder setTextBody:messageText];
        }
        else {
            [builder setHTMLBody:messageText];
        }
    }
    else {
        SM_LOG_WARNING(@"messageText is not set");
    }

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

- (id)initWithMessageText:(NSString*)messageText plainText:(Boolean)plainText subject:(NSString*)subject from:(MCOAddress*)from to:(NSArray*)to cc:(NSArray*)cc bcc:(NSArray*)bcc attachmentItems:(NSArray*)attachmentItems account:(SMUserAccount*)account {
    self = [super init];
    
    if(self) {
        _account = account;
        _plainText = plainText;
        _mcoMessageBuilder = [SMMessageBuilder createMessage:messageText plainText:plainText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:attachmentItems];
        _attachments = attachmentItems;
        _creationDate = _mcoMessageBuilder.header.date;
        _threadId = (((uint64_t)rand()) << 32) | rand();
        _uid = rand(); // TODO: generate a uid nicely!!!
        
        NSAssert(_creationDate != nil, @"_creationDate is nil");
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    
    if (self) {
        NSString *messageText = [coder decodeObjectForKey:@"messageText"];
        Boolean plainText = [coder decodeBoolForKey:@"plainText"];
        NSString *subject = [coder decodeObjectForKey:@"subject"];
        MCOAddress *from = [coder decodeObjectForKey:@"from"];
        NSArray *to = [coder decodeObjectForKey:@"to"];
        NSArray *cc = [coder decodeObjectForKey:@"cc"];
        NSArray *bcc = [coder decodeObjectForKey:@"bcc"];
        NSArray *attachmentItems = [coder decodeObjectForKey:@"attachmentItems"];
        NSDate *creationDate = [coder decodeObjectForKey:@"creationDate"];
        uint64_t threadId = [coder decodeInt64ForKey:@"threadId"];
        uint32_t uid = [coder decodeInt32ForKey:@"uid"];
    
        _mcoMessageBuilder = [SMMessageBuilder createMessage:messageText plainText:plainText subject:subject from:from to:to cc:cc bcc:bcc attachmentItems:attachmentItems];
        _plainText = plainText;
        _attachments = attachmentItems;
        _creationDate = creationDate;
        _threadId = threadId;
        _uid = uid;
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
    [coder encodeBool:_plainText forKey:@"plainText"];
    [coder encodeObject:_attachments forKey:@"attachmentItems"];
    [coder encodeObject:_creationDate forKey:@"creationDate"];
    [coder encodeInt64:_threadId forKey:@"threadId"];
    [coder encodeInt32:_uid forKey:@"uid"];
}

@end
