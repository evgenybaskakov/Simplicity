//
//  SMAttachmentItem.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAttachmentItem.h"

@implementation SMAttachmentItem {
    MCOAttachment *_mcoAttachment;
    NSString *_filePath;
}

- (id)initWithMCOAttachment:(MCOAttachment*)mcoAttachment {
	self = [super init];
	
	if(self) {
        _mcoAttachment = mcoAttachment;
	}

	return self;
}

- (id)initWithFilePath:(NSString*)filePath {
    self = [super init];
    
    if(self) {
        _filePath = filePath;
        _mcoAttachment = [MCOAttachment attachmentWithContentsOfFile:filePath];
        NSAssert(_mcoAttachment, @"could not create attachment from file %@", filePath);
    }
    
    return self;
}

- (NSString*)fileName {
	return _mcoAttachment.filename;
}

- (NSString*)filePath {
    return _filePath;
}

- (NSData*)fileData {
	return _mcoAttachment.data;
}

- (Boolean)writeAttachmentTo:(NSURL*)baseUrl {
	return [self writeAttachmentTo:baseUrl withFileName:[self fileName]];
}

- (Boolean)writeAttachmentTo:(NSURL*)baseUrl withFileName:(NSString*)fileName {
	// TODO: write to the message attachments folder
	// TODO: write only if not written yet (compare checksum?)
	// TODO: write asynchronously
	NSString *encodedFileName = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)fileName, NULL, (__bridge CFStringRef)@"!*'();:@&=+$,/?%#[] ", kCFStringEncodingUTF8);

	NSURL *fullUrl = [NSURL URLWithString:encodedFileName relativeToURL:baseUrl];
	NSData *fileData = [self fileData];
	
	NSError *writeError = nil;
	if(![fileData writeToURL:fullUrl options:NSDataWritingAtomic error:&writeError]) {
		SM_LOG_DEBUG(@"Could not write file %@: %@", fullUrl, writeError);
		return FALSE;
	}
	
	SM_LOG_DEBUG(@"File written: %@", fullUrl);
	return TRUE;
}

@end
