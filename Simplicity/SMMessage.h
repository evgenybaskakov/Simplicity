//
//  SMMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/3/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@class SMAddress;

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
    @protected BOOL _hasAttachments;
    @protected SMAddress *_fromAddress;
}

@property (readonly) MCOMessageHeader *parsedHeader; // TODO: remove
@property (readonly) MCOIMAPMessage *imapMessage;
@property (readonly) SMAddress *fromAddress;
@property (readonly) NSArray<MCOAddress*> *toAddressList;
@property (readonly) NSArray<MCOAddress*> *ccAddressList;
@property (readonly) NSArray<NSString*> *parsedToAddressList;
@property (readonly) NSArray<NSString*> *parsedCcAddressList;
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
@property (readonly) BOOL draft;

@property (nonatomic) MCOMessageParser *msgParser;
@property (nonatomic) NSString *plainTextBody;
@property (nonatomic) NSArray *attachments;
@property (nonatomic) BOOL hasAttachments;

@property (nonatomic) BOOL unseen;
@property (nonatomic) BOOL flagged;

@property SMMessageUpdateStatus updateStatus;

+ (NSString*)parseAddress:(MCOAddress*)address;

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName;
- (BOOL)updateImapMessage:(MCOIMAPMessage*)m;
- (NSString*)localizedDate;
- (BOOL)hasData;
- (void)addLabel:(NSString*)label;
- (void)removeLabel:(NSString*)label;

@end
