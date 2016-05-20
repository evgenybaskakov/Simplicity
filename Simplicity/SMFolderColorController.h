//
//  SMFolderColorController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/8/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"

@class SMMessageThread;
@class SMFolder;
                                              
@interface SMFolderColorController : SMUserAccountDataObject

+ (NSColor*)randomLabelColor;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)setFolderColor:(NSString*)folderName color:(NSColor*)color;
- (void)deleteFolderColor:(NSString*)folderName;
- (NSColor*)colorForFolder:(NSString*)folderName;
- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels;

@end
