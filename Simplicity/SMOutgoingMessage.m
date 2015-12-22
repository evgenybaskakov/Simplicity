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

@implementation SMOutgoingMessage {
    SMMessageBuilder *_messageBuilder;
}

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder {
    self = [super init];
    
    if(self) {
        _messageBuilder = messageBuilder;
        _data = _messageBuilder.mcoMessageBuilder.data;
    }
    
    return self;
}

- (uint32_t)uid {
    return rand(); // TODO: generate a uid!!!
}

- (uint64_t)threadId {
    const uint64_t num = (((uint64_t)rand()) << 32) | rand();
    return num;
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
        return @"";
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
    SM_FATAL(@"Cannot fetch inline attachements for outgoig message");
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
    
    NSAssert(_msgParser, @"no html parser");
    
    _htmlBodyRendering = [ _msgParser htmlBodyRendering ];
    
    SM_LOG_DEBUG(@"html body '%@'", _htmlBodyRendering);
    
    return _htmlBodyRendering;
}

@end
