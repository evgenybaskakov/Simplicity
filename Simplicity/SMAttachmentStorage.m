//
//  SMMessageAttachmentStorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMFileUtils.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMUserAccount.h"
#import "SMAttachmentStorage.h"

@implementation SMAttachmentStorage

- (void)storeAttachment:(NSData *)data folder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId filename:(NSString*)filename account:(SMUserAccount*)account {
    NSAssert(data, @"bad data");
    
    NSURL *attachmentDir = [[self attachmentDirectoryForFolder:folder uid:uid account:account] URLByAppendingPathComponent:contentId isDirectory:YES];
    
    if(![SMFileUtils createDirectory:attachmentDir.path]) {
        SM_LOG_ERROR(@"cannot create directory '%@'", attachmentDir.path);
        return;
    }

    if(filename == nil) {
        filename = @"attachment-data";
    }
    
    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:filename];
    NSString *attachmentFilePath = attachmentFile.path;
    
    if(![data writeToFile:attachmentFilePath atomically:YES]) {
        SM_LOG_ERROR(@"cannot write file '%@' (%lu bytes)", attachmentFilePath, (unsigned long)[data length]);
    } else {
        SM_LOG_DEBUG(@"file %@ (%lu bytes) written successfully", attachmentFilePath, (unsigned long)[data length]);
    }
}

- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder account:(SMUserAccount*)account {
    NSURL *attachmentDir = [[self attachmentDirectoryForFolder:folder uid:uid account:account] URLByAppendingPathComponent:contentId isDirectory:YES];
    
    return [self firstFile:attachmentDir];
}

- (NSURL*)attachmentDirectoryForFolder:(NSString *)folder uid:(uint32_t)uid account:(SMUserAccount*)account {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    NSInteger accountIdx = [appDelegate.accounts indexOfObject:account];
    
    NSString *accountCacheDirPath = [preferencesController cacheDirPath:accountIdx];
    NSAssert(accountCacheDirPath != nil, @"accountCacheDirPath is nil");
    
    return [NSURL fileURLWithPath:folder relativeToURL:[NSURL fileURLWithPath:accountCacheDirPath isDirectory:YES]];
}

- (NSURL*)draftAttachmentLocation:(NSString*)contentId {
    NSURL *attachmentDir = [[SMAppDelegate draftTempDir] URLByAppendingPathComponent:contentId isDirectory:YES];

    return [self firstFile:attachmentDir];
}

- (NSURL*)firstFile:(NSURL*)url {
    NSError *error;
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:url.path error:&error];
    if(dirFiles == nil || dirFiles.count == 0) {
        SM_LOG_ERROR(@"files not found in '%@'", url.path);
        return nil;
    }
    
    return [url URLByAppendingPathComponent:dirFiles[0]];
}

@end
