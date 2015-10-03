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
    NSString *_localFilePath;
}

- (id)initWithMCOAttachment:(MCOAttachment*)mcoAttachment {
	self = [super init];
	
	if(self) {
        _mcoAttachment = mcoAttachment;
	}

	return self;
}

- (id)initWithLocalFilePath:(NSString*)localFilePath {
    self = [super init];
    
    if(self) {
        _localFilePath = localFilePath;
        _mcoAttachment = [MCOAttachment attachmentWithContentsOfFile:_localFilePath];
        NSAssert(_mcoAttachment, @"could not create attachment from file %@", _localFilePath);
    }
    
    return self;
}

- (NSString*)fileName {
	return _mcoAttachment.filename;
}

- (NSString*)localFilePath {
    return _localFilePath;
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
    NSString *encodedFileName = [fileName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[] "]];
    
//	NSString *encodedFileName = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)fileName, NULL, (__bridge CFStringRef)@"!*'();:@&=+$,/?%#[] ", kCFStringEncodingUTF8);

	NSURL *fullUrl = [NSURL URLWithString:encodedFileName relativeToURL:baseUrl];
	NSData *fileData = [self fileData];
	
	NSError *writeError = nil;
	if(![fileData writeToURL:fullUrl options:NSDataWritingAtomic error:&writeError]) {
		SM_LOG_DEBUG(@"Could not write file %@: %@", fullUrl, writeError);
		return FALSE;
	}
	
	SM_LOG_WARNING(@"File written: %@", fullUrl);
	return TRUE;
}

@end
