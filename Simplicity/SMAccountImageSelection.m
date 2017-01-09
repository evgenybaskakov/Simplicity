//
//  SMAccountImageSelection.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/10/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAccountImageSelection.h"

static const CGFloat MIN_ACCOUNT_IMAGE_SIZE = 64;
static const CGFloat MAX_ACCOUNT_IMAGE_SIZE = 1024;

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
            NSString *imagePath = [accountImageURL path];
            NSString *imageFileName = [imagePath lastPathComponent];
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
            
            if(image == nil) {
                NSAlert *alert = [[NSAlert alloc] init];
                
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:[NSString stringWithFormat:@"Error loading file %@. Please select another image file.", imageFileName]];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert runModal];

                return nil;
            }
            else if(image.size.width < MIN_ACCOUNT_IMAGE_SIZE || image.size.height < MIN_ACCOUNT_IMAGE_SIZE) {
                NSAlert *alert = [[NSAlert alloc] init];
                
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:[NSString stringWithFormat:@"Size of the selected image is %g x %g. Please select an image with size at least %g x %g.", image.size.width, image.size.height, MIN_ACCOUNT_IMAGE_SIZE, MIN_ACCOUNT_IMAGE_SIZE]];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert runModal];
                
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

@end
