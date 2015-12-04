//
//  SMFolderColorController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/8/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMFolder.h"
#import "SMMessageThread.h"
#import "SMFolderColorController.h"

@implementation SMFolderColorController {
    NSMutableDictionary *_folderColors;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _folderColors = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

static NSColor *randomColor() {
    CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
    CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
    CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
    NSColor *color = [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
    return color;
}

- (NSColor*)colorForFolder:(NSString*)folderName {
    NSColor *color = [_folderColors objectForKey:folderName];

    if(color == nil) {
        color = randomColor();

        [self setFolderColor:folderName color:color];
    }
    
    return color;
}

- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels {
    NSMutableArray *bookmarkColors = [NSMutableArray array];
    
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];
    NSColor *mainColor = (folder != nil && folder.kind == SMFolderKindRegular)? [[appController folderColorController] colorForFolder:folder.fullName] : nil;
    
    [labels removeAllObjects];

    if(mainColor != nil) {
        [bookmarkColors addObject:mainColor];
        
        if(mainColor != nil)
            [labels addObject:folder.fullName];
    }
    
    for(NSString *label in messageThread.labels) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMAppController *appController = [appDelegate appController];
        
        if([label characterAtIndex:0] != '\\') {
            NSColor *color = [[appController folderColorController] colorForFolder:label];
            
            if(color != mainColor) {
                [bookmarkColors addObject:color];
                [labels addObject:label];
            }
        }
    }
    
    return bookmarkColors;
}

- (void)setFolderColor:(NSString*)folderName color:(NSColor*)color {
    [_folderColors setObject:color forKey:folderName];
}

@end
