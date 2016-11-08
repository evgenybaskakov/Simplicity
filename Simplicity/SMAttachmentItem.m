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

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    
    if (self) {
        NSString *attachmentFilename = [coder decodeObjectForKey:@"_mcoAttachment.filename"];
        NSData *attachmentData = [coder decodeObjectForKey:@"_mcoAttachment.data"];
        _localFilePath = [coder decodeObjectForKey:@"_localFilePath"];
        _mcoAttachment = [MCOAttachment attachmentWithData:attachmentData filename:attachmentFilename];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_mcoAttachment.filename forKey:@"_mcoAttachment.filename"];
    [coder encodeObject:_mcoAttachment.data forKey:@"_mcoAttachment.data"];
    [coder encodeObject:_localFilePath forKey:@"_localFilePath"];
}

- (NSString*)fileName {
    NSString *mcoFilename = _mcoAttachment.filename;
    
    if(mcoFilename != nil) {
        return mcoFilename;
    }
    
    return @"Untitled";
}

- (NSString*)localFilePath {
    return _localFilePath;
}

- (NSData*)fileData {
    return _mcoAttachment.data;
}

- (BOOL)writeAttachmentTo:(NSURL*)baseUrl {
    return [self writeAttachmentTo:baseUrl withFileName:[self fileName]];
}

- (BOOL)writeAttachmentTo:(NSURL*)baseUrl withFileName:(NSString*)fileName {
    // TODO: write to the message attachments folder
    // TODO: write only if not written yet (compare checksum?)
    // TODO: write asynchronously
    NSString *encodedFileName = [fileName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];

    NSURL *fullUrl = [NSURL URLWithString:encodedFileName relativeToURL:baseUrl];
    NSAssert(fullUrl != nil, @"could not construct full URL from base URL '%@', filename '%@'", baseUrl, fileName);
    
    NSData *fileData = [self fileData];
    NSAssert(fileData != nil, @"attachment file data is absent");
    
    NSError *writeError = nil;
    if(![fileData writeToURL:fullUrl options:NSDataWritingAtomic error:&writeError]) {
        SM_LOG_ERROR(@"Could not write file %@: %@", fullUrl, writeError);
        return FALSE;
    }
    
    SM_LOG_WARNING(@"File written: %@", fullUrl);
    return TRUE;
}

@end
