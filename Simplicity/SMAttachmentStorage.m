//
//  SMMessageAttachmentStorage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/29/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMAttachmentStorage.h"

@interface SMAttachmentStorage()

- (NSURL*)attachmentDirectoryForFolder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId;

@end

@implementation SMAttachmentStorage

- (void)storeAttachment:(NSData *)data folder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId {
    NSAssert(data, @"bad data");
    
    NSURL *attachmentDir = [self attachmentDirectoryForFolder:folder uid:uid contentId:contentId];
    
    if(![self createDirectory:attachmentDir]) {
        SM_LOG_DEBUG(@"cannot create directory '%@' for attachment '%@'", [attachmentDir path], contentId);
        
        return;
    }

    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:contentId];
    NSString *attachmentFilePath = [attachmentFile path];
    
    if(![data writeToFile:attachmentFilePath atomically:YES]) {
        SM_LOG_DEBUG(@"cannot write file '%@' (%lu bytes)", attachmentFilePath, (unsigned long)[data length]);
    } else {
        SM_LOG_DEBUG(@"file %@ (%lu bytes) written successfully", attachmentFilePath, (unsigned long)[data length]);
    }
}

- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder {
    NSAssert(contentId != nil, @"contentId is nil");
    
    NSURL *attachmentDir = [self attachmentDirectoryForFolder:folder uid:uid contentId:contentId];
    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:contentId];

    return attachmentFile;
}

- (NSURL*)attachmentDirectoryForFolder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];

    NSString *accountCacheDirPath = [preferencesController cacheDirPath:appDelegate.currentAccountIdx];
    NSAssert(accountCacheDirPath != nil, @"accountCacheDirPath is nil");
    
    return [NSURL fileURLWithPath:folder relativeToURL:[NSURL fileURLWithPath:accountCacheDirPath isDirectory:YES]];
}

- (BOOL)createDirectory:(NSURL*)dir {
    NSString *dirPath = [dir path];
    NSAssert(dirPath != nil, @"dirPath is nil");
    
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        SM_LOG_ERROR(@"failed to create directory '%@', error: %@", dirPath, error);
        return NO;
    }

    SM_LOG_DEBUG(@"directory '%@' created successfully", dirPath);
    return YES;
}

@end
