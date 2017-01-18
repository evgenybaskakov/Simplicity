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
#import "SMMessage.h"
#import "SMAttachmentStorage.h"

@implementation SMAttachmentStorage

- (BOOL)storeAttachment:(NSData *)data folder:(NSString *)folder uid:(uint32_t)uid contentId:(NSString *)contentId filename:(NSString*)filename account:(SMUserAccount*)account {
    NSAssert(data, @"bad data");
    
    NSURL *attachmentDir = [[self attachmentDirectoryForFolder:folder uid:uid account:account] URLByAppendingPathComponent:contentId isDirectory:YES];
    
    if(![SMFileUtils createDirectory:attachmentDir.path]) {
        SM_LOG_ERROR(@"cannot create directory '%@'", attachmentDir.path);
        return FALSE;
    }

    if(filename == nil) {
        filename = @"attachment-data";
    }
    
    NSURL *attachmentFile = [attachmentDir URLByAppendingPathComponent:filename];
    NSString *attachmentFilePath = attachmentFile.path;
    
    if(![data writeToFile:attachmentFilePath atomically:YES]) {
        SM_LOG_ERROR(@"cannot write file '%@' (%lu bytes)", attachmentFilePath, (unsigned long)[data length]);
        return FALSE;
    }
    
    SM_LOG_DEBUG(@"file %@ (%lu bytes) written successfully", attachmentFilePath, (unsigned long)[data length]);
    return TRUE;
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

- (NSURL*)draftInlineAttachmentLocation:(NSString*)contentId {
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

- (BOOL)storeDraftInlineAttachment:(NSURL *)fileUrl contentId:(NSString *)contentId {
    NSURL *dirUrl = [[SMAppDelegate draftTempDir] URLByAppendingPathComponent:contentId];
    
    NSString *dirPath = [dirUrl path];
    NSAssert(dirPath != nil, @"dirPath is nil");
    
    if(![SMFileUtils createDirectory:dirPath]) {
        SM_LOG_ERROR(@"failed to create directory '%@'", dirPath);
        return FALSE;
    }
    
    // Copy of the original file.
    NSURL *cacheFileUrl = [dirUrl URLByAppendingPathComponent:fileUrl.lastPathComponent];
    
    // Remove any existing file, if any (don't check for errors)
    [[NSFileManager defaultManager] removeItemAtURL:cacheFileUrl error:nil];
    
    // TODO: cleanup as soon as the message is sent or saved as a draft
    NSError *error;
    if(![[NSFileManager defaultManager] copyItemAtURL:fileUrl toURL:cacheFileUrl error:&error]) {
        SM_LOG_ERROR(@"failed to copy '%@' to %@: %@", fileUrl, cacheFileUrl, error);
        return FALSE;
    }
    
    return TRUE;
}

- (void)fetchMessageInlineAttachments:(SMMessage *)message account:(SMUserAccount*)account {
    NSString *remoteFolder = message.remoteFolder;
    uint32_t uid = message.uid;
    
    NSArray *attachments = message.inlineAttachments;
    if(attachments == nil) {
        SM_LOG_WARNING(@"no inline attachments for message uid %u", uid);
        return;
    }
    
    MCOIMAPMessage *imapMessage = message.imapMessage;
    if(imapMessage == nil) {
        SM_LOG_WARNING(@"no imap message for message uid %u", uid);
        return;
    }
    
    // TODO: fetch inline attachments on demand
    // TODO: refresh current view of the message loaded from DB without attachments
    for(MCOAttachment *attachment in attachments) {
        // TODO: async operation
        NSString *attachmentContentId = [attachment contentID] != nil? [attachment contentID] : [attachment uniqueID];
        
        SM_LOG_DEBUG(@"message uid %u, attachment unique id %@, contentID %@, body %@", uid, [attachment uniqueID], attachmentContentId, attachment);
        
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        NSURL *attachmentUrl = [appDelegate.attachmentStorage attachmentLocation:attachmentContentId uid:uid folder:remoteFolder account:account];
        
        NSError *err;
        if([attachmentUrl checkResourceIsReachableAndReturnError:&err] == YES) {
            SM_LOG_DEBUG(@"stored attachment exists at '%@'", attachmentUrl);
            continue;
        }
        
        NSData *attachmentData = [attachment data];

        if(attachmentData) {
            [appDelegate.attachmentStorage storeAttachment:attachmentData folder:remoteFolder uid:uid contentId:attachmentContentId filename:attachment.filename account:account];
        } else {
            MCOAbstractPart *part = [imapMessage partForUniqueID:[attachment uniqueID]];
            
            NSAssert(part, @"Cannot find inline attachment part");
            NSAssert([part isKindOfClass:[MCOIMAPPart class]], @"Bad inline attachment part type");
            
            MCOIMAPPart *imapPart = (MCOIMAPPart*)part;
            NSString *partId = [imapPart partID];
            
            NSAssert([attachmentContentId isEqualToString:[imapPart contentID]], @"Attachment contentId is not equal to part contentId");
            
            SM_LOG_DEBUG(@"part %@, id %@, contentID %@", part, partId, [imapPart contentID]);
            
            // TODO: for older sessions, terminate attachment fetching
            NSAssert(account.imapSession, @"bad session");
            
            MCOIMAPFetchContentOperation *op = [account.imapSession fetchMessageAttachmentOperationWithFolder:remoteFolder uid:uid partID:partId encoding:[imapPart encoding] urgent:YES];
            
            [op start:^(NSError * error, NSData * data) {
                if (error.code == MCOErrorNone) {
                    NSAssert(data, @"no data");
                    
                    [appDelegate.attachmentStorage storeAttachment:data folder:remoteFolder uid:uid contentId:imapPart.contentID filename:imapPart.filename account:account];
                } else {
                    SM_LOG_ERROR(@"Error downloading message body for msg uid %u, part unique id %@: %@", uid, partId, error);
                }
            }];
        }
    }
}

@end
