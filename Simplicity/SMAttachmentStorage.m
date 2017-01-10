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
#import "SMAttachmentStorage.h"

@implementation SMAttachmentStorage

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self) {
        
    }
    
    return self;
}

- (void)storeAttachment:(NSData *)data folder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId filename:(NSString*)filename {
    NSAssert(data, @"bad data");
    
    NSURL *attachmentDir = [[self attachmentDirectoryForFolder:folder uid:uid] URLByAppendingPathComponent:contentId isDirectory:YES];
    
    if(![SMFileUtils createDirectory:attachmentDir.path]) {
        SM_LOG_ERROR(@"cannot create directory '%@'", attachmentDir.path);
        return;
    }

    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:filename];
    NSString *attachmentFilePath = attachmentFile.path;
    
    if(![data writeToFile:attachmentFilePath atomically:YES]) {
        SM_LOG_ERROR(@"cannot write file '%@' (%lu bytes)", attachmentFilePath, (unsigned long)[data length]);
    } else {
        SM_LOG_DEBUG(@"file %@ (%lu bytes) written successfully", attachmentFilePath, (unsigned long)[data length]);
    }
}

- (NSURL*)attachmentLocation:(NSString*)contentId uid:(uint32_t)uid folder:(NSString*)folder {
    NSAssert(contentId != nil, @"contentId is nil");
    
    NSURL *attachmentDir = [[self attachmentDirectoryForFolder:folder uid:uid] URLByAppendingPathComponent:contentId isDirectory:YES];
    
    NSError *error;
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:attachmentDir.path error:&error];
    if(dirFiles == nil || dirFiles.count == 0) {
        SM_LOG_ERROR(@"files not found in '%@'", attachmentDir.path);
        return nil;
    }
    
    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:dirFiles[0]];

    return attachmentFile;
}

- (NSURL*)attachmentDirectoryForFolder:(NSString *)folder uid:(uint32_t)uid {
    NSAssert(!_account.unified, @"current account is unified, attachment storage is stubbed");
    
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];

    NSInteger accountIdx = [appDelegate.accounts indexOfObject:(SMUserAccount*)_account];
    
    NSString *accountCacheDirPath = [preferencesController cacheDirPath:accountIdx];
    NSAssert(accountCacheDirPath != nil, @"accountCacheDirPath is nil");
    
    return [NSURL fileURLWithPath:folder relativeToURL:[NSURL fileURLWithPath:accountCacheDirPath isDirectory:YES]];
}

@end
