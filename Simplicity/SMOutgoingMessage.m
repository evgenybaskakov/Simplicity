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

@implementation SMOutgoingMessage {
    uint32_t _uid;
    uint64_t _threadId;
}

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder uid:(uint32_t)uid {
    self = [super init];
    
    if(self) {
        _messageBuilder = messageBuilder;
        _data = _messageBuilder.mcoMessageBuilder.data;
        _uid = uid;
        _threadId = (((uint64_t)rand()) << 32) | rand();

        NSMutableArray *mcoAttachments = [NSMutableArray array];
        for(SMAttachmentItem *item in messageBuilder.attachments) {
            [mcoAttachments addObject:item.mcoAttachment];
        }
        
        _attachments = mcoAttachments;
        _hasAttachments = _attachments.count > 0;
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

- (NSString*)bodyPreview {
    if(_bodyPreview != nil) {
        return _bodyPreview;
    }
    
    NSString *plainText = [_messageBuilder.mcoMessageBuilder plainTextBodyRendering];
    
    if(plainText == nil) {
        return nil;
    }
    
    NSUInteger maxLen = [SMMessage maxBodyPreviewLength];
    if(plainText.length <= maxLen) {
        _bodyPreview = plainText;
    }
    else {
        _bodyPreview = [plainText substringToIndex:maxLen];
    }
    
    return _bodyPreview;
}

- (void)reclaimData {
    SM_FATAL(@"Cannot reclaim outgoig message");
}

- (void)setData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments {
    SM_FATAL(@"Cannot set external data for outgoing message");
}

- (NSData*)data {
    return _data;
}

- (BOOL)hasData {
    return _data != nil;
}

- (Boolean)updateImapMessage:(MCOIMAPMessage*)m {
    SM_FATAL(@"Cannot update outgoig message");
    return NO;
}

- (Boolean)unseen {
    return NO;
}

- (void)setUnseen:(Boolean)unseen {
    SM_FATAL(@"Cannot set seen/unseen outgoig message");
}

- (Boolean)flagged {
    return NO;
}

- (void)setFlagged:(Boolean)flagged {
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
    
    if(!_data) {
        // TODO: Request urgently for the data
        // TODO: Request future update
        SM_LOG_DEBUG(@"no data for message uid %u", self.uid);
        return nil;
    }
    
    _htmlBodyRendering = _messageBuilder.mcoMessageBuilder.htmlBodyRendering;
    
    NSAssert(_htmlBodyRendering, @"no html parser");
    
    SM_LOG_DEBUG(@"html body '%@'", _htmlBodyRendering);
    
    return _htmlBodyRendering;
}

@end
