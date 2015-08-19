//
//  SMMessage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/3/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

@interface SMMessage : NSObject <MCOHTMLRendererDelegate>

@property (readonly) MCOMessageHeader *header;

@property (readonly) NSString *from;
@property (readonly) NSString *subject;
@property (readonly) NSDate *date;
@property (readonly) uint32_t uid;
@property (readonly) NSString *htmlBodyRendering;
@property (readonly) NSString *remoteFolder;
@property (readonly) Boolean hasAttachments;
@property (readonly) NSArray *attachments;
@property (readonly) NSArray *labels;
@property (readonly) Boolean reclaimed;

@property Boolean unseen;
@property Boolean flagged;

@property (assign) NSData *data;

@property BOOL updated;

+ (NSString*)parseAddress:(MCOAddress*)address;

- (id)initWithRawValues:(int)uid date:(NSDate*)date from:(const unsigned char*)from subject:(const unsigned char*)subject data:(const void*)data dataLength:(int)dataLength remoteFolder:(NSString*)remoteFolderName;

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName;

- (BOOL)hasData;
- (void)fetchInlineAttachments;

- (Boolean)updateImapMessage:(MCOIMAPMessage*)m;

- (NSString*)localizedDate;

- (NSArray*)parsedToAddressList;
- (NSArray*)parsedCcAddressList;

- (void)reclaimData;

@end
