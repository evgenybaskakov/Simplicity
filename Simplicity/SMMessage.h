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

@interface SMMessage : NSObject <MCOHTMLRendererDelegate> {
    @protected MCOMessageParser *_msgParser;
    @protected NSString *_plainTextBody;
    @protected NSAttributedString *_htmlMessageBody;
    @protected NSString *_htmlBodyRendering;
    @protected NSArray *_attachments;
    @protected Boolean _hasAttachments;
}

@property (readonly) MCOMessageHeader *parsedHeader; // TODO: remove
@property (readonly) MCOIMAPMessage *imapMessage;
@property (readonly) MCOAddress *fromAddress;
@property (readonly) NSArray *toAddressList;
@property (readonly) NSArray *ccAddressList;
@property (readonly) NSArray *parsedToAddressList;
@property (readonly) NSArray *parsedCcAddressList;
@property (readonly) NSString *subject;
@property (readonly) NSDate *date;
@property (readonly) uint32_t uid;
@property (readonly) uint64_t messageId;
@property (readonly) uint64_t threadId;
@property (readonly) NSString *htmlBodyRendering;
@property (readonly) NSArray *htmlInlineAttachments;
@property (readonly) NSString *remoteFolder;
@property (readonly) NSArray *labels;
@property (readonly) NSUInteger messageSize;
@property (readonly) Boolean draft;

@property (nonatomic) MCOMessageParser *msgParser;
@property (nonatomic) NSString *plainTextBody;
@property (nonatomic) NSArray *attachments;
@property (nonatomic) Boolean hasAttachments;

@property (nonatomic) Boolean unseen;
@property (nonatomic) Boolean flagged;

@property SMMessageUpdateStatus updateStatus;

+ (NSString*)parseAddress:(MCOAddress*)address;

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName;
- (Boolean)updateImapMessage:(MCOIMAPMessage*)m;
- (NSString*)localizedDate;
- (BOOL)hasData;

@end
