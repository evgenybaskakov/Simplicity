//
//  SMOutgoingMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessageBuilder.h"
#import "SMOutgoingMessage.h"
#import "SMAttachmentItem.h"
#import "SMAddress.h"

@implementation SMOutgoingMessage {
    uint32_t _uid;
    uint64_t _threadId;
}

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder {
    self = [super init];
    
    if(self) {
        _messageBuilder = messageBuilder;
        _uid = _messageBuilder.uid;
        _threadId = _messageBuilder.threadId;
        
        MCOAddress *from = _messageBuilder.mcoMessageBuilder.header.from;
        NSAssert(from, @"no from field");
        
        _fromAddress = [[SMAddress alloc] initWithMCOAddress:from];
        
        NSMutableArray *mcoAttachments = [NSMutableArray array];
        for(SMAttachmentItem *item in messageBuilder.attachments) {
            [mcoAttachments addObject:item.mcoAttachment];
        }
        
        _attachments = mcoAttachments;
        _hasAttachments = _attachments.count != 0 || _inlineAttachments.count != 0;
    }
    
    return self;
}

- (uint32_t)uid {
    return _uid;
}

- (uint64_t)threadId {
    return _threadId;
}

- (NSDate*)date {
    NSAssert(_messageBuilder.creationDate != nil, @"_messageBuilder.creationDate is nil");
    return _messageBuilder.creationDate;
}

- (MCOMessageHeader*)parsedHeader {
    return [_messageBuilder.mcoMessageBuilder header];
}

- (MCOMessageHeader*)imapHeader {
    return [_messageBuilder.mcoMessageBuilder header];
}

- (NSString*)plainTextBody {
    if(_plainTextBody != nil) {
        return _plainTextBody;
    }
    
    _plainTextBody = [_messageBuilder.mcoMessageBuilder plainTextBodyRendering];
    
    return _plainTextBody;
}

- (void)setData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments {
    SM_FATAL(@"Cannot set external data for outgoing message");
}

- (NSUInteger)messageSize {
    return 0;
}

- (BOOL)hasData {
    return YES;
}

- (BOOL)isDraft {
    return NO;
}

- (BOOL)updateImapMessage:(MCOIMAPMessage*)m {
    SM_FATAL(@"Cannot update outgoig message");
    return NO;
}

- (BOOL)unseen {
    return NO;
}

- (void)setUnseen:(BOOL)unseen {
    SM_FATAL(@"Cannot set seen/unseen outgoig message");
}

- (BOOL)flagged {
    return NO;
}

- (void)setFlagged:(BOOL)flagged {
    SM_FATAL(@"Cannot set flagged/unflagged outgoig message");
}

- (void)fetchInlineAttachments {
    SM_LOG_INFO(@"No inline attachements for outgoig message");
}

- (NSString*)htmlBodyRendering {
    if(_htmlBodyRendering) {
        SM_LOG_DEBUG(@"html body for message uid %u already generated", self.uid);
        return _htmlBodyRendering;
    }
    
    _htmlBodyRendering = _messageBuilder.mcoMessageBuilder.htmlBodyRendering;
    
    NSAssert(_htmlBodyRendering, @"no html parser");
    
    SM_LOG_DEBUG(@"html body '%@'", _htmlBodyRendering);
    
    return _htmlBodyRendering;
}

@end
