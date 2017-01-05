//
//  SMFileUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/5/17.
//  Copyright © 2017 Evgeny Baskakov. All rights reserved.
//

#import "SMFileUtils.h"

@implementation SMFileUtils

+ (BOOL)imageFileType:(NSString*)filename {
    NSString *attachmentFilenameLowercase = [filename lowercaseString];
    NSString *fileExtension = [attachmentFilenameLowercase pathExtension];
    
    CFStringRef cfFileExtension = (__bridge CFStringRef)fileExtension;
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, cfFileExtension, NULL);
    
    return UTTypeConformsTo(fileUTI, kUTTypeImage)? YES : NO;
}

@end
