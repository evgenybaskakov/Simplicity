//
//  SMAttachmentItem.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAttachmentItem.h"

@implementation SMAttachmentItem {
    MCOAttachment *_mcoAttachment;
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
        _mcoAttachment = [MCOAttachment attachmentWithContentsOfFile:filePath];
        NSAssert(_mcoAttachment, @"could not create attachment from file %@", filePath);
    }
    
    return self;
}

- (NSString*)fileName {
	return _mcoAttachment.filename;
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
		NSLog(@"%s: Could not write file %@: %@", __func__, fullUrl, writeError);
		return FALSE;
	}
	
	NSLog(@"%s: File written: %@", __func__, fullUrl);
	return TRUE;
}

@end
