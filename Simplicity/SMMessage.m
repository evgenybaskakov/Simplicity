//
//  SMMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/3/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
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

- (id)initWithMCOIMAPMessage:(MCOIMAPMessage*)m remoteFolder:(NSString*)remoteFolderName {
	NSAssert(m, @"imap message is nil");
	
	self = [ super init ];
	
	if(self) {
		_imapMessage = m;
		_createdFromDB = NO;
		_remoteFolder = remoteFolderName;
		_labels = m.gmailLabels;

        SM_LOG_DEBUG(@"thread id %llu, subject '%@', labels %@", m.gmailThreadID, m.header.subject, m.gmailLabels);
        SM_LOG_DEBUG(@"uid %u, object %@, date %@", [ m uid ], m, [[m header] date]);
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
	
    SM_LOG_DEBUG(@"from: %@, sent date %@, received date %@", [header from], [header date], [header receivedDate]);

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

- (void)reclaimData {
    _reclaimed = YES;
    
    [self setData:nil parser:nil attachments:nil];
}

- (void)setData:(NSData*)data parser:(MCOMessageParser*)parser attachments:(NSArray*)attachments {
    if(data != nil) {
        if(_data == nil) {
            _data = data;
            _msgParser = parser;
            _attachments = attachments;
            _hasAttachments = attachments.count > 0;
            
            NSAssert(_msgParser, @"no message parser");
        }
        
        _reclaimed = NO;
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
		SM_LOG_DEBUG(@"IMAP message is set");

		_imapMessage = m;

		return YES;
	} else if(_imapMessage.originalFlags != m.originalFlags) {
		// TODO: be careful there because in future new flags should combine with the local flags
		
		SM_LOG_DEBUG(@"IMAP message uid %u original flags have changed", _imapMessage.uid);

		_imapMessage = m;

		return YES;
	} else {
		return NO;
	}
}

- (Boolean)unseen {
	if(_imapMessage == nil) {
		SM_LOG_DEBUG(@"IMAP message is not set");
		return NO;
	}
    
	return (_imapMessage.flags & MCOMessageFlagSeen) == 0;
}

- (void)setUnseen:(Boolean)unseen {
    if(_imapMessage == nil) {
        SM_LOG_DEBUG(@"IMAP message is not set");
        return;
    }
    
    if(unseen) {
        _imapMessage.flags &= ~MCOMessageFlagSeen;
    }
    else {
        _imapMessage.flags |= MCOMessageFlagSeen;
    }
    
}

- (Boolean)flagged {
	if(_imapMessage == nil) {
		SM_LOG_DEBUG(@"IMAP message is not set");
		return NO;
	}
	
	return (_imapMessage.flags & MCOMessageFlagFlagged) != 0;
}

- (void)setFlagged:(Boolean)flagged {
    if(_imapMessage == nil) {
        SM_LOG_DEBUG(@"IMAP message is not set");
        return;
    }
    
    if(flagged) {
        _imapMessage.flags |= MCOMessageFlagFlagged;
    }
    else {
        _imapMessage.flags &= ~MCOMessageFlagFlagged;
    }
    
}

- (void)fetchInlineAttachments {
    // TODO: "_data" may be nil, if fetchMessageBody happens to call from another _localFolder,
    //       other from the local folder where the message header fetch was initiated
	NSAssert(_data, @"bad _data (reclaimed: %u)", _reclaimed);
	NSAssert(_msgParser, @"bad _msgParser");
	
	if(_createdFromDB && _imapMessage == nil) {
		// TODO: handle this!!!!
		SM_LOG_DEBUG(@"no attachments available for message loaded from DB");
		return;
	}
	
    SM_LOG_DEBUG(@"imap message class %@, message body %@", [_imapMessage class], _imapMessage);

	NSAssert(_imapMessage, @"bad _imapMessage");

	NSArray *attachments = [_msgParser htmlInlineAttachments];
	
	// TODO: fetch inline attachments on demand
	// TODO: refresh current view of the message loaded from DB without attachments
	for(MCOAttachment *attachment in attachments) {
		const uint32_t uid = [_imapMessage uid];

		NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
		NSData *attachmentData = [attachment data];

		SM_LOG_DEBUG(@"message uid %u, attachment unique id %@, contentID %@, body %@", uid, [attachment uniqueID], attachmentContentId, attachment);
		
		SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

		NSURL *attachmentUrl = [[[appDelegate model] attachmentStorage] attachmentLocation:attachmentContentId uid:uid folder:_remoteFolder];
		
		NSError *err;
		if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
			SM_LOG_DEBUG(@"stored attachment exists at '%@'", attachmentUrl);
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
			
			SM_LOG_DEBUG(@"part %@, id %@, contentID %@", part, partId, [imapPart contentID]);

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
					SM_LOG_ERROR(@"Error downloading message body for msg uid %u, part unique id %@: %@", uid, partId, error);
				}
			}];
		}
	}
}

- (NSString*)htmlBodyRendering {
	if(_htmlBodyRendering) {
		SM_LOG_DEBUG(@"html body for message uid %u already generated", [_imapMessage uid]);
		return _htmlBodyRendering;
	}
	
	if(!_data) {
		// TODO: Request urgently for the data
		// TODO: Request future update
		SM_LOG_DEBUG(@"no data for message uid %u", [_imapMessage uid]);
		return nil;
	}

	NSAssert(_msgParser, @"no html parser");
	
	_htmlBodyRendering = [ _msgParser htmlBodyRendering ];

	SM_LOG_DEBUG(@"html body '%@'", _htmlBodyRendering);
	
	return _htmlBodyRendering;
}

- (BOOL) MCOAbstractMessage:(MCOAbstractMessage *)msg canPreviewPart:(MCOAbstractPart *)part {
	SM_LOG_DEBUG(@"???");
	return YES;
}
- (BOOL) MCOAbstractMessage:(MCOAbstractMessage *)msg shouldShowPart:(MCOAbstractPart *)part {
	SM_LOG_DEBUG(@"???");
	return YES;
}
- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForHeader:(MCOMessageHeader *)header {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForPart:(MCOAbstractPart *)part {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForMainHeader:(MCOMessageHeader *)header {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForImage:(MCOAbstractPart *)header {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForAttachment:(MCOAbstractPart *)part {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage_templateForMessage:(MCOAbstractMessage *)msg {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessage:(MCOAbstractMessagePart *)part {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessageHeader:(MCOMessageHeader *)header {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage_templateForAttachmentSeparator:(MCOAbstractMessage *)msg {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForPart:(NSString *)html {
	SM_LOG_DEBUG(@"???");
	return nil;
}
- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForMessage:(NSString *)html {
	SM_LOG_DEBUG(@"???");
	return nil;
}

// TODO: cache trimmed strings
+ (NSString*)trimTextField:(NSString*)str {
	return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
