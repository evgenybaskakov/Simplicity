//
//  SMAccountImageSelection.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/10/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAccountImageSelection.h"

static const NSUInteger MIN_ACCOUNT_IMAGE_SIZE = 64;
static const NSUInteger MAX_ACCOUNT_IMAGE_SIZE = 1024;

@implementation SMAccountImageSelection

+ (NSImage*)defaultImage {
    return [NSImage imageNamed:NSImageNameUserGuest];
}

+ (NSImage*)promptForImage {
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowedFileTypes:@[@"png", @"jpg", @"jpeg"]];
    
    [openDlg setPrompt:@"Select account image"];
    
    if([openDlg runModal] == NSModalResponseOK) {
        NSURL *accountImageURL = [openDlg URL];
        
        if(accountImageURL != nil) {
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:[accountImageURL path]];
            
            if(image == nil) {
                // TODO
                SM_LOG_ERROR(@"Could not load image file '%@'", accountImageURL);
                return nil;
            }
            else if(image.size.width < MIN_ACCOUNT_IMAGE_SIZE || image.size.height < MIN_ACCOUNT_IMAGE_SIZE) {
                // TODO
                SM_LOG_ERROR(@"Bad image file '%@' size %g x %g", accountImageURL, image.size.width, image.size.height);
                return nil;
            }
            else {
                if(MAX(image.size.width, image.size.height) > MAX_ACCOUNT_IMAGE_SIZE) {
                    CGFloat sizeRatio = MAX(image.size.width, image.size.height) / MAX_ACCOUNT_IMAGE_SIZE;
                    NSSize newSize = NSMakeSize(image.size.width / sizeRatio, image.size.height / sizeRatio);
                    
                    [image setSize:newSize];
                }
                
                return image;
            }
        }
        else {
            SM_LOG_ERROR(@"Could not load account URL '%@'", accountImageURL);
            return nil;
        }
    }
    
    SM_LOG_INFO(@"No message selected");
    return nil;
}

+ (void)saveImageFile:(NSString*)filePath image:(NSImage*)image {
    NSData *imageData = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];

    imageData = [imageRep representationUsingType:NSPNGFileType properties:imageProps];
    
    if(![imageData writeToFile:filePath atomically:NO]) {
        SM_LOG_ERROR(@"Could not save account image to '%@'", filePath);
    }
}

@end
