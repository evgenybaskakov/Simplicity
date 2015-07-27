//
//  SMMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/3/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMSimplicityContainer.h"
#import "SMAttachmentStorage.h"
#import "SMMessage.h"

@interface SMMessage()

+ (NSString*)trimTextField:(NSString*)str;

@end

@implementation SMMessage {
	BOOL _createdFromDB;
	
	uint32_t _uidDB;
	NSDate *_dateDB;
	NSString *_fromDB;
	NSString *_subjectDB;
	MCOIMAPMessage *_imapMessage;
	MCOMessageParser *_msgParser;
	NSAttributedString *_htmlMessageBody;
	NSData *_data;
	Boolean _hasAttachments;
}

@synthesize htmlBodyRendering = _htmlBodyRendering;

// TODO: uids not properly used here - they may be changed between sessions!!!
- (id)initWithRawValues:(int)uid date:(NSDate*)date from:(const unsigned char*)from subject:(const unsigned char*)subject data:(const void*)data dataLength:(int)dataLength remoteFolder:(NSString*)remoteFolderName {

	self = [ super init ];
	
	if(self) {
		//NSLog(@"%s: uid %u, date %@", __FUNCTION__, uid, date);
		
		_uidDB = uid;
		_dateDB = date;
		_fromDB = [NSString stringWithUTF8String:(const char*)from];
		_subjectDB = [NSString stringWithUTF8String:(const char*)subject];
		_createdFromDB = YES;
		_remoteFolder = remoteFolderName;
		_labels = [NSArray array]; // TODO

		[self setData:[NSData dataWithBytes:data length:dataLength]];
	}
	
	return self;
}

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName {
	NSAssert(m, @"imap message is nil");
	
	self = [ super init ];
	
	if(self) {
		_imapMessage = m;
		_createdFromDB = NO;
		_remoteFolder = remoteFolderName;
		_labels = m.gmailLabels;

//		NSLog(@"%s: thread id %llu, subject '%@', labels %@", __FUNCTION__, m.gmailThreadID, m.header.subject, m.gmailLabels);
//		NSLog(@"%s: uid %u, object %@, date %@", __FUNCTION__, [ m uid ], m, [[m header] date]);
	}

	return self;
}

- (MCOIMAPMessage*)getImapMessage {
	return _imapMessage;
}

- (MCOMessageHeader*)header {
//	return [_imapMessage header]; TODO!!
	return [_msgParser header];
}

static NSString *unquote(NSString *s) {
	if(s.length > 2 && [s characterAtIndex:0] == '\'' && [s characterAtIndex:s.length-1] == '\'')
		return [s substringWithRange:NSMakeRange(1, s.length-2)];
	else
		return s;
}

+ (NSString*)parseAddress:(MCOAddress*)address {
	NSString *fromDisplayName = [address displayName];
	if(fromDisplayName != nil) {
		NSString *trimmedFromDisplayName = [SMMessage trimTextField:fromDisplayName];
		NSAssert(trimmedFromDisplayName, @"trimmed name nil");
		if([trimmedFromDisplayName length] > 0)
			return unquote(trimmedFromDisplayName);
	}
	
	NSString *name = [address nonEncodedRFC822String];
	if(name != nil && [name compare:@"invalid"] != NSOrderedSame)
		return unquote(name);
	
	NSString *mailbox = [address mailbox];
	NSAssert(mailbox, @"no from mailbox");
	
	NSString *mailboxTrimmed = [self trimTextField:mailbox];
	if(mailboxTrimmed != nil && [mailboxTrimmed length] > 0)
		return unquote(mailboxTrimmed);
	
	/*
	 MCOAddress *sender = [header sender];
	 NSAssert(sender, @"no sender");
	 
	 NSString *senderDisplayName = [sender displayName];
	 if(senderDisplayName) {
	 NSString *trimmedsenderDisplayName = [self trimTextField:senderDisplayName];
	 if([trimmedsenderDisplayName length] > 0)
	 return trimmedsenderDisplayName;
	 }
	 
	 NSString *senderName = [sender nonEncodedRFC822String];
	 if(senderName && [senderName compare:@"invalid"] != NSOrderedSame)
	 return senderName;
	 NSString *senderMailbox = [sender mailbox];
	 NSAssert(senderMailbox, @"no sender mailbox");
	 
	 return senderMailbox;
	 */
	
	return @"<unknown>";
}

- (NSString*)from {
	if(_createdFromDB) {
		NSAssert(_fromDB != nil, @"_fromDB is nil");
		return _fromDB;
	}
	
	MCOMessageHeader *header = [_imapMessage header];
	NSAssert(header, @"no header");
	
	MCOAddress *from = [header from];
	NSAssert(header, @"no from field");

	return [SMMessage parseAddress:from];
}

- (NSString*)subject {
	if(_createdFromDB)
		return _subjectDB;

	MCOMessageHeader *header = [_imapMessage header];
	NSAssert(header, @"no header");

	NSString *subject = [header subject];
	if(subject) {
		// note: two-pass replacement replacement loop here
		NSString *trimmedSubject = [[[SMMessage trimTextField:subject] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"\r" withString:@""];

		if([trimmedSubject length] > 0) {
			return trimmedSubject;
		}
	}
	
	return @"<no subject>";
}

- (NSArray*)parsedToAddressList {
    NSArray *toAddressArray = [self.header to];
    NSMutableArray *newToArray = [[NSMutableArray alloc] initWithCapacity:toAddressArray.count];
    
    for(NSUInteger i = 0; i < toAddressArray.count; i++)
        newToArray[i] = [SMMessage parseAddress:toAddressArray[i]];
    
    return newToArray;
}

- (NSArray*)parsedCcAddressList {
    NSArray *ccAddressArray = [self.header cc];
    
    if(ccAddressArray != nil && ccAddressArray.count > 0) {
        NSMutableArray *newCcArray = [[NSMutableArray alloc] initWithCapacity:ccAddressArray.count];
        
        for(NSUInteger i = 0; i < ccAddressArray.count; i++)
            newCcArray[i] = [SMMessage parseAddress:ccAddressArray[i]];
        
        return newCcArray;
    }
    
    return nil;
}

- (NSDate*)date {
	if(_createdFromDB)
		return _dateDB;
	
	MCOMessageHeader *header = [_imapMessage header];
	NSAssert(header, @"no header");
	
//	NSLog(@"from: %@, sent date %@, received date %@", [header from], [header date], [header receivedDate]);

	return [header date];
}

- (NSString*)localizedDate {
	NSDate *messageDate = [self date];
	NSDateComponents *messageDateComponents = [[NSCalendar currentCalendar] components:NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:messageDate];
	
	NSDateComponents *today = [[NSCalendar currentCalendar] components:NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	
	if([today day] == [messageDateComponents day] && [today month] == [messageDateComponents month] && [today year] == [messageDateComponents year] && [today era] == [messageDateComponents era]) {
		return [NSDateFormatter localizedStringFromDate:messageDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
	} else {
		return [NSDateFormatter localizedStringFromDate:messageDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
	}
}

- (uint32_t)uid {
	if(_createdFromDB) {
		if(_imapMessage)
			NSAssert(_uidDB == [_imapMessage uid], @"actual/db uid mismatch");
		
		return _uidDB;
	}

	return [_imapMessage uid];
}

- (void)setData:(NSData*)data {
	if(data != nil) {
		if(_data == nil) {
			_data = data;
			_msgParser = [MCOMessageParser messageParserWithData:data];
			_attachments = _msgParser.attachments;
			_hasAttachments = _attachments.count > 0;
			
			NSAssert(_msgParser, @"cannot create message parser");
		}
	} else {
		_data = nil;
		_msgParser = nil;
		_attachments = nil;
		_htmlBodyRendering = nil;

		// do not reset the attachment count
		// because it is important to show the attachments flag
		// in the messages list

		// TODO: figure out a nice way
	}
}

- (NSData*)data {
	return _data;
}

- (BOOL)hasData {
	return _data != nil;
}

- (Boolean)updateImapMessage:(MCOIMAPMessage*)m {
	NSAssert(m, @"bad param message");
	
	if(_imapMessage == nil) {
		NSLog(@"%s: IMAP message is set", __FUNCTION__);

		_imapMessage = m;

		return YES;
	} else if(_imapMessage.originalFlags != m.originalFlags) {
		// TODO: be careful there because in future new flags should combine with the local flags
		
		NSLog(@"%s: IMAP message uid %u original flags have changed", __FUNCTION__, _imapMessage.uid);

		_imapMessage = m;

		return YES;
	} else {
		return NO;
	}
}

- (Boolean)unseen {
	if(_imapMessage == nil) {
		NSLog(@"%s: IMAP message is not set", __FUNCTION__);
		return NO;
	}
	
	return (_imapMessage.originalFlags & MCOMessageFlagSeen) == 0;
}

- (Boolean)flagged {
	if(_imapMessage == nil) {
		NSLog(@"%s: IMAP message is not set", __FUNCTION__);
		return NO;
	}
	
	return (_imapMessage.originalFlags & MCOMessageFlagFlagged) != 0;
}

- (void)fetchInlineAttachments {
	NSAssert(_data, @"bad _data");
	NSAssert(_msgParser, @"bad _msgParser");
	
	if(_createdFromDB && _imapMessage == nil) {
		// TODO: handle this!!!!
		NSLog(@"%s: no attachments available for message loaded from DB", __FUNCTION__);
		return;
	}
	
//	NSLog(@"%s: imap message class %@, message body %@", __FUNCTION__, [_imapMessage class], _imapMessage);

	NSAssert(_imapMessage, @"bad _imapMessage");

	NSArray *attachments = [_msgParser htmlInlineAttachments];
	
	// TODO: fetch inline attachments on demand
	// TODO: refresh current view of the message loaded from DB without attachments
	for(MCOAttachment *attachment in attachments) {
		const uint32_t uid = [_imapMessage uid];

		NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
		NSData *attachmentData = [attachment data];

		//NSLog(@"%s: message uid %u, attachment unique id %@, contentID %@, body %@", __FUNCTION__, uid, [attachment uniqueID], attachmentContentId, attachment);
		
		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

		NSURL *attachmentUrl = [[[appDelegate model] attachmentStorage] attachmentLocation:attachmentContentId uid:uid folder:_remoteFolder];
		
		NSError *err;
		if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
			//NSLog(@"%s: stored attachment exists at '%@'", __FUNCTION__, attachmentUrl);
			continue;
		}
		
		if(attachmentData) {
			[[[appDelegate model] attachmentStorage] storeAttachment:attachmentData folder:_remoteFolder uid:uid contentId:attachmentContentId];
		} else {
			MCOAbstractPart *part = [_imapMessage partForUniqueID:[attachment uniqueID]];
			
			NSAssert(part, @"Cannot find inline attachment part");
			NSAssert([part isKindOfClass:[MCOIMAPPart class]], @"Bad inline attachment part type");
			
			MCOIMAPPart *imapPart = (MCOIMAPPart*)part;
			NSString *partId = [imapPart partID];
			
			NSAssert([attachmentContentId isEqualToString:[imapPart contentID]], @"Attachment contentId is not equal to part contentId");
			
			//NSLog(@"%s: part %@, id %@, contentID %@", __FUNCTION__, part, partId, [imapPart contentID]);

			MCOIMAPSession *session = [[appDelegate model] imapSession];
			
			// TODO: for older sessions, terminate attachment fetching
			NSAssert(session, @"bad session");
			
			MCOIMAPFetchContentOperation *op = [session fetchMessageAttachmentOperationWithFolder:_remoteFolder uid:uid partID:partId encoding:[imapPart encoding] urgent:YES];
			
			// TODO: check if there is a leak if imapPart is accessed in this block!!!
			[op start:^(NSError * error, NSData * data) {
				if ([error code] == MCOErrorNone) {
					NSAssert(data, @"no data");
					
					SMAppDelegate *appDelegate =  [[NSApplication sharedApplication] delegate];
					[[[appDelegate model] attachmentStorage] storeAttachment:data folder:_remoteFolder uid:uid contentId:[imapPart contentID]];
				} else {
					NSLog(@"%s: Error downloading message body for msg uid %u, part unique id %@: %@", __func__, uid, partId, error);
				}
			}];
		}
	}
}

- (NSString*)htmlBodyRendering {
	if(_htmlBodyRendering) {
		//NSLog(@"%s: html body for message uid %u already generated", __FUNCTION__, [_imapMessage uid]);
		return _htmlBodyRendering;
	}
	
	if(!_data) {
		// TODO: Request urgently for the data
		// TODO: Request future update
		//NSLog(@"%s: no data for message uid %u", __FUNCTION__, [_imapMessage uid]);
		return nil;
	}

	NSAssert(_msgParser, @"no html parser");
	
	_htmlBodyRendering = [ _msgParser htmlBodyRendering ];

	//NSLog(@"html body '%@'", _htmlBodyRendering);
	
	return _htmlBodyRendering;
}

- (BOOL) MCOAbstractMessage:(MCOAbstractMessage *)msg canPreviewPart:(MCOAbstractPart *)part {
	NSLog(@"%s", __FUNCTION__);
	return YES;
}
- (BOOL) MCOAbstractMessage:(MCOAbstractMessage *)msg shouldShowPart:(MCOAbstractPart *)part {
	NSLog(@"%s", __FUNCTION__);
	return YES;
}
- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForHeader:(MCOMessageHeader *)header {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForPart:(MCOAbstractPart *)part {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForMainHeader:(MCOMessageHeader *)header {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForImage:(MCOAbstractPart *)header {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForAttachment:(MCOAbstractPart *)part {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage_templateForMessage:(MCOAbstractMessage *)msg {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessage:(MCOAbstractMessagePart *)part {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessageHeader:(MCOMessageHeader *)header {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage_templateForAttachmentSeparator:(MCOAbstractMessage *)msg {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForPart:(NSString *)html {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForMessage:(NSString *)html {
	NSLog(@"%s", __FUNCTION__);
	return nil;
}

// TODO: cache trimmed strings
+ (NSString*)trimTextField:(NSString*)str {
	return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
