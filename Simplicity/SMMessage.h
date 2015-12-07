//
//  SMMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/3/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

typedef NS_ENUM(NSUInteger, SMMessageUpdateStatus) {
    SMMessageUpdateStatus_Unknown = 0,
    SMMessageUpdateStatus_Persisted,
    SMMessageUpdateStatus_New,
};

@interface SMMessage : NSObject <MCOHTMLRendererDelegate>

@property (readonly) MCOMessageHeader *header;
@property (readonly) MCOIMAPMessage *imapMessage;
@property (readonly) MCOAddress *fromAddress;
@property (readonly) NSArray *toAddressList;
@property (readonly) NSArray *ccAddressList;
@property (readonly) NSArray *parsedToAddressList;
@property (readonly) NSArray *parsedCcAddressList;
@property (readonly) NSString *subject;
@property (readonly) NSDate *date;
@property (readonly) uint32_t uid;
@property (readonly) NSString *htmlBodyRendering;
@property (readonly) NSString *remoteFolder;
@property (readonly) Boolean hasAttachments;
@property (readonly) NSArray *attachments;
@property (readonly) NSArray *labels;
@property (readonly) Boolean reclaimed;
@property (readonly) NSString *bodyPreview;

@property Boolean unseen;
@property Boolean flagged;

@property (readonly) NSData *data;

@property SMMessageUpdateStatus updateStatus;

+ (NSString*)parseAddress:(MCOAddress*)address;

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName;

- (void)setData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments;

- (BOOL)hasData;
- (void)fetchInlineAttachments;

- (Boolean)updateImapMessage:(MCOIMAPMessage*)m;

- (NSString*)localizedDate;

- (void)reclaimData;

@end
