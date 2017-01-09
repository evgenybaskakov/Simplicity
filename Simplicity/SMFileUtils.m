//
//  SMFileUtils.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/5/17.
//  Copyright © 2017 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMFileUtils.h"

@implementation SMFileUtils

+ (BOOL)imageFileType:(NSString*)filename {
    NSString *attachmentFilenameLowercase = [filename lowercaseString];
    NSString *fileExtension = [attachmentFilenameLowercase pathExtension];
    
    CFStringRef cfFileExtension = (__bridge CFStringRef)fileExtension;
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, cfFileExtension, NULL);
    
    return UTTypeConformsTo(fileUTI, kUTTypeImage)? YES : NO;
}

+ (BOOL)saveImageFile:(NSString*)filePath image:(NSImage*)image {
    NSData *imageData = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    
    imageData = [imageRep representationUsingType:NSPNGFileType properties:imageProps];
    
    if(![imageData writeToFile:filePath atomically:NO]) {
        SM_LOG_ERROR(@"Could not save account image to '%@'", filePath);
        return FALSE;
    }
    
    return TRUE;
}

+ (BOOL)createDirectory:(NSString*)dirPath {
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        SM_LOG_ERROR(@"failed to create directory '%@', error: %@", dirPath, error);
        return NO;
    }
    
    SM_LOG_DEBUG(@"directory '%@' created successfully", dirPath);
    return YES;
}

@end
